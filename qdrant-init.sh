#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status.

# This script initializes Qdrant collections using curl to interact with the REST API.

# 1. VERIFY API KEY
# Stop immediately if the QDRANT_API_KEY is not available in the container.
if [ -z "$QDRANT_API_KEY" ]; then
  echo "[ERROR] QDRANT_API_KEY environment variable is not set. Please check your .env file and docker-compose configuration."
  exit 1
fi

# Set variables
QDRANT_HOST="${QDRANT_HOST:-http://qdrant:6333}"
VECTOR_SIZE=768
COLLECTIONS="user_knowledge group_knowledge general_knowledge"

# Loop through each collection name.
for COLLECTION_NAME in $COLLECTIONS; do
    echo "---"
    echo "Checking for collection: $COLLECTION_NAME"

    # 2. CHECK IF COLLECTION EXISTS
    # Use curl to check if the collection exists, passing the API key.
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "api-key: ${QDRANT_API_KEY}" "$QDRANT_HOST/collections/$COLLECTION_NAME")

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Collection '$COLLECTION_NAME' already exists. Skipping creation."
    else
        echo "Collection '$COLLECTION_NAME' does not exist. Creating now..."

        # Construct the JSON payload for the create request.
        JSON_PAYLOAD=$(printf '{"vectors":{"size":%d,"distance":"Cosine","on_disk":true}}' "$VECTOR_SIZE")

        # 3. CREATE THE COLLECTION
        # Use curl with a PUT request, checking the response code directly.
        CREATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
             -H "Content-Type: application/json" \
             -H "api-key: ${QDRANT_API_KEY}" \
             -d "$JSON_PAYLOAD" \
             "$QDRANT_HOST/collections/$COLLECTION_NAME")

        # 4. VERIFY CREATION
        # Check if the creation was successful (HTTP 200 OK).
        if [ "$CREATE_STATUS" -eq 200 ]; then
            echo "Collection '$COLLECTION_NAME' created successfully."
        else
            echo "[ERROR] Failed to create collection '$COLLECTION_NAME'. Qdrant returned HTTP status: $CREATE_STATUS"
            echo "[ERROR] Qdrant's response was:"
            # Run the command again, but this time print the output from Qdrant for debugging.
            curl -s -X PUT \
                 -H "Content-Type: application/json" \
                 -H "api-key: ${QDRANT_API_KEY}" \
                 -d "$JSON_PAYLOAD" \
                 "$QDRANT_HOST/collections/$COLLECTION_NAME"
            echo "" # Newline for readability
            exit 1 # Exit with an error code to stop the process.
        fi
    fi
done

echo "---"
echo "Qdrant initialization complete."
