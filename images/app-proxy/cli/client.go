/*
 Copyright 2020 Google Inc. All rights reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/dgrijalva/jwt-go"
	huproxy "github.com/google/huproxy/lib"
	"github.com/gorilla/websocket"
	"github.com/salrashid123/oauth2oidc"
	"golang.org/x/oauth2"
)

type CredentialCache struct {
	oauth2oidc.TokenResponse
	BrokerCookie string `json:"broker_cookie"`
	Endpoint     string `json:"endpoint"`
}

const defaultAudience = "BROKER_CLIENT_ID"
const defaultClientID = "DESKTOP_APP_CLIENT_ID"
const defaultClientSecret = "DESKTOP_APP_CLIENT_SECRET"

var (
	flCredentialFile = flag.String("credential_file", "creds.json", "Credential file with id_token, refresh_token, and broker_cookie")
	writeTimeout     = flag.Duration("write_timeout", 10*time.Second, "Write timeout")
	brokerAudience   = flag.String("audience", "", "Broker web app OAuth client ID")
	appClientID      = flag.String("clientID", "", "Desktop app OAuth client ID")
	appClientSecret  = flag.String("clientSecret", "", "Desktop app OAuth client secret")
	endpoint         = flag.String("endpoint", "DEFAULT_ENDPOINT", "Broker base URL, ex: broker.endpoints.PROJECT_ID.cloud.goog")
	remotePort       = flag.Int("remote_port", 22, "Remote port")
	localPort        = flag.Int("local_port", 0, "Local port, default to remote_port")
	localAddr        = flag.String("local_addr", "127.0.0.1", "Local address to listen on")
	appName          = flag.String("app", "", "Name of broker app to connect to")
	userCookie       = flag.String("cookie", "", "Broker user cookie for per-user routing")

	verbose = flag.Bool("verbose", false, "Verbose.")
)

func dialError(url string, resp *http.Response, err error) {
	if resp != nil {
		extra := ""
		if *verbose {
			b, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				log.Printf("Failed to read HTTP body: %v", err)
			}
			extra = "Body:\n" + string(b)
		}
		log.Fatalf("%s: HTTP error: %d %s\n%s", err, resp.StatusCode, resp.Status, extra)

	}
	log.Fatalf("Dial to %q fail: %v", url, err)
}

func main() {
	flag.Parse()

	if len(*endpoint) == 0 {
		log.Fatalf("missing endpoint arg")
	}
	url := fmt.Sprintf("wss://%s/%s/connect/proxy/localhost/%d", *endpoint, *appName, *remotePort)
	cookieUrl := fmt.Sprintf("https://%s/broker/%s/", *endpoint, *appName)

	if len(*appName) == 0 {
		log.Fatalf("missing app arg")
	}

	if *localPort == 0 {
		*localPort = *remotePort
	}

	if *verbose {
		log.Printf("huproxyclient %s", huproxy.Version)
	}

	head := map[string][]string{}

	audience := *brokerAudience
	clientID := *appClientID
	clientSecret := *appClientSecret

	if len(audience) == 0 {
		// Use default audience
		audience = defaultAudience
		if audience == "BROKER_CLIENT_ID" {
			log.Fatalf("invalid audience: %v", audience)
		}
	}

	if len(clientID) == 0 {
		// Use default client ID
		clientID = defaultClientID
		if clientID == "DESKTOP_APP_CLIENT_ID" {
			log.Fatalf("invalid client ID: %v", clientID)
		}
	}

	if len(clientSecret) == 0 {
		// Use default client secret
		clientSecret = defaultClientSecret
		if clientSecret == "DESKTOP_APP_CLIENT_SECRET" {
			log.Fatalf("invalid client secret: %v", clientSecret)
		}
	}

	conf := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://accounts.google.com/o/oauth2/auth",
			TokenURL: "https://oauth2.googleapis.com/token",
		},
		RedirectURL: "urn:ietf:wg:oauth:2.0:oob",
		Scopes:      []string{"https://www.googleapis.com/auth/userinfo.email"},
	}

	var refreshToken string
	var brokerCookie string
	var cache CredentialCache
	_, err := os.Stat(*flCredentialFile)
	if *flCredentialFile == "" || os.IsNotExist(err) {
		lurl := conf.AuthCodeURL("code")
		fmt.Printf("\nVisit the URL for the auth dialog and enter the authorization code  \n\n%s\n", lurl)
		fmt.Printf("\nEnter code:  ")
		input := bufio.NewScanner(os.Stdin)
		input.Scan()
		newTok, err := conf.Exchange(oauth2.NoContext, input.Text())
		if err != nil {
			log.Fatalf("Cloud not exchange Token %v", err)
		}
		refreshToken = newTok.RefreshToken
	} else {
		f, err := os.Open(*flCredentialFile)
		if err != nil {
			log.Fatalf("Could not open credential File %v", err)
		}
		defer f.Close()

		err = json.NewDecoder(f).Decode(&cache)
		if err != nil {
			log.Fatalf("Could not parse credential File %v", err)
		}
		refreshToken = cache.RefreshToken

		var parser *jwt.Parser
		parser = new(jwt.Parser)
		tt, _, err := parser.ParseUnverified(cache.IDToken, &jwt.StandardClaims{})
		if err != nil {
			log.Fatalf("Could not parse saved id_tokne File %v", err)
		}

		c, ok := tt.Claims.(*jwt.StandardClaims)
		err = tt.Claims.Valid()
		if ok && err == nil {
			if c.Audience != audience {
				log.Fatalf("Token audience does not match")
			}
		}

		brokerCookie = cache.BrokerCookie
	}

	tokenResp, err := oauth2oidc.GetIdToken(audience, clientID, clientSecret, refreshToken)
	if err != nil {
		log.Fatalf("Failed to get ID token: %v", err)
	}
	idToken := tokenResp.IDToken

	if len(brokerCookie) == 0 {
		// Get broker cookie
		client := http.Client{}
		var cookie []*http.Cookie
		req, _ := http.NewRequest("GET", cookieUrl, nil)
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", idToken))
		resp, err := client.Do(req)
		if err != nil {
			return
		}
		cookie = resp.Cookies()

		// Find cookie
		cookieName := fmt.Sprintf("broker_%s", *appName)
		cookieValue := ""
		for _, c := range cookie {
			if c.Name == cookieName {
				cookieValue = c.Value
			}
		}
		if len(cookieValue) == 0 {
			log.Fatalf("failed to get broker cookie for app")
		}
		brokerCookie = fmt.Sprintf("%s=%s", cookieName, cookieValue)
	}

	// Cache token
	cache.IDToken = idToken
	cache.RefreshToken = refreshToken
	cache.BrokerCookie = brokerCookie
	cache.Endpoint = *endpoint

	f, err := os.OpenFile(*flCredentialFile, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		log.Fatalf("Could not parse saved token File %v", err)
	}
	defer f.Close()
	json.NewEncoder(f).Encode(cache)

	head["Authorization"] = []string{
		fmt.Sprintf("Bearer %s", idToken),
	}

	head["Cookie"] = []string{
		brokerCookie,
	}

	localListen := fmt.Sprintf("%s:%d", *localAddr, *localPort)

	log.Printf("Listening for connections on %s to broker app %s port %d", localListen, *appName, *remotePort)
	for {
		// Local TCP listener
		l, err := net.Listen("tcp", localListen)
		if err != nil {
			log.Fatalf("error listening on local port: %v", err)
		}
		defer l.Close()

		for {
			// Listen for an incoming connection.
			l, err := l.Accept()
			if err != nil {
				fmt.Println("Error accepting: ", err.Error())
				os.Exit(1)
			}
			// Handle connections in a new goroutine.
			go func(lconn net.Conn) {
				log.Printf("Creating new connection for client %s", lconn.RemoteAddr().String())
				handleLocalConnection(lconn, url, head)
				log.Printf("Connection closed for client %s", lconn.RemoteAddr().String())
			}(l)
		}
	}
}

func handleLocalConnection(lconn net.Conn, url string, head map[string][]string) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// connect to huproxy websocket
	dialer := websocket.Dialer{}
	rconn, resp, err := dialer.Dial(url, head)
	if err != nil {
		dialError(url, resp, err)
	}

	defer lconn.Close()
	defer rconn.Close()

	// websocket -> local socket
	go func() {
		for {
			mt, r, err := rconn.NextReader()
			if websocket.IsCloseError(err, websocket.CloseNormalClosure) {
				return
			}
			if err != nil {
				cancel()
				return
			}
			if mt != websocket.BinaryMessage {
				log.Println("invalid binary data from websocket")
			}
			if _, err := io.Copy(lconn, r); err != nil {
				log.Printf("Reading from websocket: %v", err)
				cancel()
			}
		}
	}()

	// local socket -> websocket
	for {
		if err := huproxy.File2WS(ctx, cancel, lconn, rconn); err == io.EOF {
			if err := rconn.WriteControl(websocket.CloseMessage,
				websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""),
				time.Now().Add(*writeTimeout)); err == websocket.ErrCloseSent {
			} else if err != nil {
				log.Printf("Error sending close message: %v", err)
			}
		} else if err != nil {
			log.Printf("reading from local socket: %v", err)
			cancel()
		}

		if ctx.Err() != nil {
			cancel()
			return
		}
	}
}
