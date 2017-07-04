package helpers

import (
	"net/http"
	"strings"
	"time"

	log "github.com/sirupsen/logrus"
)

var CORSOrigins = []string{ 
    {{.Origins}}
}

// Usage: HandleMiddlewares(PersonHandlerGET, MiddlewareNoCache, MiddlewareCORS)(w, r)
func HandleMiddlewares(handlerFunc http.HandlerFunc, middlewares ...func(http.HandlerFunc) http.HandlerFunc) (h http.HandlerFunc) {
	for _, mw := range middlewares {
		handlerFunc = mw(handlerFunc)
	}
	return handlerFunc
}

func MiddlewareNoCache(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		fn(w, r)
	}
}

func MiddlewareLogger(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
		fn(w, r)
		log.Debugf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	}
}

// Influenced by: https://github.com/unrolled/secure
func MiddlewareSecure(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// TLS Redirect
		if !strings.EqualFold(r.URL.Scheme, "https") {
			r.URL.Scheme = "https"

			log.Debug("MW Secure: Redirecting to ", r.URL)
			http.Redirect(w, r, r.URL.String(), http.StatusMovedPermanently)
		}

		// HSTS: add "preload" for additional security https://www.owasp.org/index.php/HTTP_Strict_Transport_Security_Cheat_Sheet
		w.Header().Set("Strict-Transport-Security","max-age=31536000; includeSubDomains")

		// XSS Prevention
		w.Header().Set("X-XSS-Protection", "1; mode=block")

		// Content nosniff
		w.Header().Set("X-Content-Type-Options", "nosniff")

		// Frame deny
		w.Header().Set("X-Frame-Options", "DENY")

		fn(w, r)
	}
}

func MiddlewareCORS(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Debug("MW CORS: Request Origin:", r.Header.Get("Origin"))

		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		if len(CORSOrigins) == 0 {
			log.Debug("No CORS Origins defined, but CORS middleware called. No header write.")
			fn(w, r)
			return
		}

		if origin := r.Header.Get("Origin"); origin != "" && valInArr(origin, CORSOrigins) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			fn(w, r)
			return
		}

		log.Debug("CORS: Bad Host")
		http.Error(w, "Bad Host", http.StatusInternalServerError)
	}
}

func valInArr(val string, arr []string) bool {
    for _, a := range arr {
        if val == a {
            return true
        }
    }
    return false
}
