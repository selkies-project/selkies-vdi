module selkies.io/connector

go 1.17

replace github.com/google/huproxy => github.com/danisla/huproxy v0.0.0-20201016000201-4378f4d94da3

require (
	github.com/dgrijalva/jwt-go v3.2.0+incompatible
	github.com/google/huproxy v0.0.0-00010101000000-000000000000
	github.com/gorilla/websocket v1.4.2
	github.com/salrashid123/oauth2oidc v1.0.0
	golang.org/x/oauth2 v0.0.0-20211104180415-d3ed0bb246c8
)

require (
	github.com/golang/protobuf v1.4.2 // indirect
	golang.org/x/net v0.7.0 // indirect
	google.golang.org/appengine v1.6.6 // indirect
	google.golang.org/protobuf v1.25.0 // indirect
)
