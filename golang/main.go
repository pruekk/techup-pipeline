package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type responseWriter struct {
	http.ResponseWriter
	statusCode   int
	responseSize int
}

func newResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{w, http.StatusOK, 0}
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(b)
	rw.responseSize += size
	return size, err
}

// Cart structure to hold cart data
type Cart struct {
	Total int `json:"total"`
	mu    sync.RWMutex
}

// Global cart instance
var cart = &Cart{Total: 0}

// Prometheus metrics
var totalRequests = prometheus.NewCounterVec(
	prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Number of get requests.",
	},
	[]string{"path"},
)

var responseStatus = prometheus.NewCounterVec(
	prometheus.CounterOpts{
		Name: "response_status",
		Help: "Status of HTTP response",
	},
	[]string{"status"},
)

var httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
	Name: "http_response_time_seconds",
	Help: "Duration of HTTP requests.",
}, []string{"path"})

// Cart GAUGE metric
var cartTotal = promauto.NewGauge(prometheus.GaugeOpts{
	Name: "cart_total_items",
	Help: "Total number of items in the cart",
})

func prometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		route := mux.CurrentRoute(r)
		path, _ := route.GetPathTemplate()

		timer := prometheus.NewTimer(httpDuration.WithLabelValues(path))
		rw := newResponseWriter(w)
		next.ServeHTTP(rw, r)

		statusCode := rw.statusCode
		responseSize := rw.responseSize
		duration := time.Since(start)

		// Print traffic information
		fmt.Printf("[%s] %s %s - %d %d bytes - %v\n",
			time.Now().Format("2006-01-02 15:04:05"),
			r.Method,
			r.URL.Path,
			statusCode,
			responseSize,
			duration,
		)

		responseStatus.WithLabelValues(strconv.Itoa(statusCode)).Inc()
		totalRequests.WithLabelValues(path).Inc()

		timer.ObserveDuration()
	})
}

// Cart handlers
func cartIncrease(w http.ResponseWriter, r *http.Request) {
	cart.mu.Lock()
	cart.Total++
	cartTotal.Set(float64(cart.Total))
	cart.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"action":  "increase",
		"total":   cart.Total,
		"message": "Item added to cart",
	})
}

func cartDecrease(w http.ResponseWriter, r *http.Request) {
	cart.mu.Lock()
	if cart.Total > 0 {
		cart.Total--
	}
	cartTotal.Set(float64(cart.Total))
	cart.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"action":  "decrease",
		"total":   cart.Total,
		"message": "Item removed from cart",
	})
}

func cartTotalHandler(w http.ResponseWriter, r *http.Request) {
	cart.mu.RLock()
	total := cart.Total
	cart.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"total":   total,
		"message": "Current cart total",
	})
}

func init() {
	prometheus.Register(totalRequests)
	prometheus.Register(responseStatus)
	prometheus.Register(httpDuration)
	
	// Initialize cart total metric
	cartTotal.Set(0)
}

func main() {
	router := mux.NewRouter()
	router.Use(prometheusMiddleware)

	// Prometheus endpoint
	router.Path("/metrics").Handler(promhttp.Handler())

	// Cart endpoints
	router.HandleFunc("/cart/increase", cartIncrease).Methods("POST", "GET")
	router.HandleFunc("/cart/decrease", cartDecrease).Methods("POST", "GET")
	router.HandleFunc("/cart/total", cartTotalHandler).Methods("GET")

	// Serving static files
	router.PathPrefix("/").Handler(http.FileServer(http.Dir("./static/")))

	fmt.Println("Serving requests on port 8080")
	fmt.Println("Traffic logging enabled")
	fmt.Println("Cart API endpoints:")
	fmt.Println("  GET/POST /cart/increase - Add item to cart")
	fmt.Println("  GET/POST /cart/decrease - Remove item from cart")
	fmt.Println("  GET /cart/total - Get cart total")
	fmt.Println("  GET /metrics - Prometheus metrics")
	
	err := http.ListenAndServe(":8080", router)
	log.Fatal(err)
}