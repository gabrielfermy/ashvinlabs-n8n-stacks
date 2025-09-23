#!/bin/sh

# This script initializes Qdrant collections using curl to interact with the REST API.
# It is a direct functional equivalent of the Python script.

# Set the Qdrant host, defaulting to localhost.
QDRANT_HOST="${QDRANT_HOST:-http://qdrant:6333}"

# Define the embedding vector size. This should match your model.
VECTOR_SIZE=768

# Define the collections to be created.
COLLECTIONS="user_knowledge group_knowledge general_knowledge"

# Loop through each collection name.
for COLLECTION_NAME in $COLLECTIONS; do
    echo "Checking for collection: $COLLECTION_NAME"

    # Use curl to check if the collection exists. The -s flag makes curl silent.
    # The -o /dev/null redirects the body to nowhere.
    # The -w "%{http_code}" prints the HTTP response code.
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$QDRANT_HOST/collections/$COLLECTION_NAME")

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Collection '$COLLECTION_NAME' already exists. Skipping creation."
    else
        echo "Collection '$COLLECTION_NAME' does not exist. Creating now..."

        # Construct the JSON payload for the create request.
        # The 'vectors' key is now a nested JSON object.
        JSON_PAYLOAD='{"vectors": {"size": '$VECTOR_SIZE', "distance": "Cosine", "on_disk": true}}'

        # Use curl with a PUT request to create the collection.
        # The -X PUT specifies the request method.
        # The -H sets the Content-Type header to application/json.
        # The -d passes the JSON payload.
        # The output of the command will show the creation status.
        curl -s -X PUT \
             -H "Content-Type: application/json" \
             -d "$JSON_PAYLOAD" \
             "$QDRANT_HOST/collections/$COLLECTION_NAME"

        echo "" # Add a newline for better formatting.
        echo "Collection '$COLLECTION_NAME' created successfully."
    fi
done

echo "Qdrant initialization complete."