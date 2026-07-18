#!/bin/bash

echo "🚀 Starting the DBMS Project..."

# Start the Flask Backend in the background
echo "🐍 Starting Flask Backend..."
source venv/bin/activate
flask run --port 5001 &
BACKEND_PID=$!

# Start the React Frontend in the background
echo "⚛️ Starting Vite Frontend..."
cd frontend
npm run dev &
FRONTEND_PID=$!

echo "✅ Both servers are running!"
echo "Press Ctrl+C to stop both servers."

# Function to clean up background processes when the script exits
function cleanup {
  echo ""
  echo "🛑 Shutting down servers..."
  kill $BACKEND_PID
  kill $FRONTEND_PID
  echo "Goodbye!"
  exit
}

# Trap the SIGINT (Ctrl+C) and EXIT signals to run the cleanup function
trap cleanup SIGINT EXIT

# Wait for all background processes to finish
wait
