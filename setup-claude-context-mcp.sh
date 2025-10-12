#!/bin/bash

# Setup Claude Context MCP for any project
# This script checks for existing installations and only installs missing components
# Usage: ./setup-claude-context-mcp.sh <project_name>

set -e  # Exit on error

# Check if project name is provided
if [ -z "$1" ]; then
    echo "Error: Project name is required"
    echo "Usage: $0 <project_name>"
    echo ""
    echo "Examples:"
    echo "  $0 localbodies"
    echo "  $0 project1"
    echo "  $0 project2"
    exit 1
fi

PROJECT_NAME="$1"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Claude Context MCP Setup for ${PROJECT_NAME} ===${NC}\n"

# Check if Docker is installed
echo -e "${BLUE}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is already installed${NC}"
else
    echo -e "${YELLOW}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

# Check if Node.js is installed
echo -e "${BLUE}Checking Node.js...${NC}"
if command -v node &> /dev/null; then
    echo -e "${GREEN}✓ Node.js is already installed ($(node --version))${NC}"
else
    echo -e "${YELLOW}✗ Node.js not found. Please install Node.js first.${NC}"
    exit 1
fi

# Check if Python3 is installed
echo -e "${BLUE}Checking Python3...${NC}"
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python3 is already installed ($(python3 --version))${NC}"
else
    echo -e "${YELLOW}✗ Python3 not found. Please install Python3 first.${NC}"
    exit 1
fi

# Check if Claude CLI is installed
echo -e "${BLUE}Checking Claude CLI...${NC}"
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓ Claude CLI is already installed ($(claude --version))${NC}"
else
    echo -e "${YELLOW}Installing Claude CLI...${NC}"
    curl -fsSL https://raw.githubusercontent.com/anthropics/claude-cli/main/install.sh | sh
    source ~/.bashrc
fi

# Check and install missing Python packages
echo -e "\n${BLUE}Checking Python packages...${NC}"
MISSING_PACKAGES=()

if ! pip3 list | grep -q "google-generativeai"; then
    MISSING_PACKAGES+=("google-generativeai")
fi

if ! pip3 list | grep -q "pymilvus"; then
    MISSING_PACKAGES+=("pymilvus")
fi

if ! pip3 list | grep -q "^flask "; then
    MISSING_PACKAGES+=("flask")
fi

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${MISSING_PACKAGES[*]}${NC}"
    pip3 install --user "${MISSING_PACKAGES[@]}"
else
    echo -e "${GREEN}✓ All required Python packages are installed${NC}"
fi

# Check and configure Gemini API Key
echo -e "\n${BLUE}Checking Gemini API Key...${NC}"
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${YELLOW}GEMINI_API_KEY not set.${NC}"
    read -p "Enter your Gemini API key: " api_key
    if [ -z "$api_key" ]; then
        echo -e "${YELLOW}Warning: No API key provided. You'll need to set GEMINI_API_KEY manually.${NC}"
    else
        export GEMINI_API_KEY="$api_key"
        # Add to bashrc if not already there
        if ! grep -q "GEMINI_API_KEY" ~/.bashrc; then
            echo "export GEMINI_API_KEY=\"$api_key\"" >> ~/.bashrc
            echo -e "${GREEN}✓ API key added to ~/.bashrc${NC}"
        fi
    fi
else
    echo -e "${GREEN}✓ GEMINI_API_KEY is already set${NC}"
fi

# Check if Milvus container is running
echo -e "\n${BLUE}Checking Milvus container...${NC}"
if docker ps -a | grep -q milvus-standalone; then
    if docker ps | grep -q milvus-standalone; then
        echo -e "${GREEN}✓ Milvus container is running${NC}"
    else
        echo -e "${YELLOW}Starting existing Milvus container...${NC}"
        docker start milvus-standalone
    fi
else
    echo -e "${YELLOW}Creating and starting Milvus container...${NC}"
    docker run -d \
      --name milvus-standalone \
      -p 19530:19530 \
      -p 9091:9091 \
      -v ~/milvus_data:/var/lib/milvus \
      milvusdb/milvus:latest \
      milvus run standalone

    echo -e "${GREEN}✓ Milvus container created and started${NC}"
    echo -e "${YELLOW}Waiting 10 seconds for Milvus to initialize...${NC}"
    sleep 10
fi

# Check if gemini-proxy directory exists
echo -e "\n${BLUE}Setting up Gemini-to-OpenAI proxy...${NC}"
if [ -d ~/gemini-proxy ]; then
    echo -e "${GREEN}✓ gemini-proxy directory exists${NC}"
else
    echo -e "${YELLOW}Creating gemini-proxy directory...${NC}"
    mkdir -p ~/gemini-proxy
fi

# Create proxy.py
cat > ~/gemini-proxy/proxy.py << 'EOF'
from flask import Flask, request, jsonify
import google.generativeai as genai
import os

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY'))

@app.route('/v1/embeddings', methods=['POST'])
def embeddings():
    data = request.json
    text = data.get('input')
    if isinstance(text, list):
        text = text[0]

    result = genai.embed_content(
        model="models/text-embedding-004",
        content=text,
        task_type="retrieval_document"
    )

    return jsonify({
        "object": "list",
        "data": [{
            "object": "embedding",
            "embedding": result['embedding'],
            "index": 0
        }],
        "model": "text-embedding-004"
    })

@app.route('/v1/models', methods=['GET'])
def models():
    return jsonify({
        "object": "list",
        "data": [{
            "id": "text-embedding-004",
            "object": "model"
        }]
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8000)
EOF

echo -e "${GREEN}✓ proxy.py created${NC}"

# Check if systemd service exists
echo -e "\n${BLUE}Setting up systemd service...${NC}"
if systemctl list-unit-files | grep -q gemini-proxy.service; then
    echo -e "${GREEN}✓ gemini-proxy service exists${NC}"
    echo -e "${YELLOW}Restarting service...${NC}"
    sudo systemctl restart gemini-proxy
else
    echo -e "${YELLOW}Creating systemd service...${NC}"

    # Get the actual GEMINI_API_KEY value
    ACTUAL_API_KEY="${GEMINI_API_KEY}"

    cat > /tmp/gemini-proxy.service << EOF
[Unit]
Description=Gemini Embedding Proxy
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/gemini-proxy
Environment="GEMINI_API_KEY=$ACTUAL_API_KEY"
ExecStart=/usr/bin/python3 $HOME/gemini-proxy/proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/gemini-proxy.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable gemini-proxy
    sudo systemctl start gemini-proxy

    echo -e "${GREEN}✓ systemd service created and started${NC}"
fi

# Wait for proxy to be ready
echo -e "${YELLOW}Waiting 3 seconds for proxy to start...${NC}"
sleep 3

# Check if MCP is already configured
echo -e "\n${BLUE}Configuring Claude MCP for ${PROJECT_NAME}...${NC}"
if claude mcp list 2>/dev/null | grep -q "code-indexer-${PROJECT_NAME}"; then
    echo -e "${GREEN}✓ MCP for ${PROJECT_NAME} already configured${NC}"
    read -p "Do you want to reconfigure it? (y/N): " reconfigure
    if [[ $reconfigure =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing existing MCP...${NC}"
        claude mcp remove code-indexer-${PROJECT_NAME}

        echo -e "${YELLOW}Adding MCP configuration...${NC}"
        claude mcp add code-indexer-${PROJECT_NAME} \
          -e EMBEDDING_PROVIDER=OpenAI \
          -e EMBEDDING_MODEL=text-embedding-004 \
          -e OPENAI_API_KEY=dummy \
          -e OPENAI_BASE_URL=http://127.0.0.1:8000/v1/ \
          -e MILVUS_ADDRESS=127.0.0.1:19530 \
          -e MILVUS_TOKEN=local \
          -e MILVUS_DATABASE=${PROJECT_NAME} \
          -- npx @zilliz/claude-context-mcp@latest

        echo -e "${GREEN}✓ MCP reconfigured${NC}"
    fi
else
    echo -e "${YELLOW}Adding MCP configuration...${NC}"
    claude mcp add code-indexer-${PROJECT_NAME} \
      -e EMBEDDING_PROVIDER=OpenAI \
      -e EMBEDDING_MODEL=text-embedding-004 \
      -e OPENAI_API_KEY=dummy \
      -e OPENAI_BASE_URL=http://127.0.0.1:8000/v1/ \
      -e MILVUS_ADDRESS=127.0.0.1:19530 \
      -e MILVUS_TOKEN=local \
      -e MILVUS_DATABASE=${PROJECT_NAME} \
      -- npx @zilliz/claude-context-mcp@latest

    echo -e "${GREEN}✓ MCP configured${NC}"
fi

# Verification
echo -e "\n${BLUE}=== Verification ===${NC}"
echo -e "${BLUE}Checking Milvus...${NC}"
if docker ps | grep -q milvus-standalone; then
    echo -e "${GREEN}✓ Milvus is running${NC}"
else
    echo -e "${YELLOW}✗ Milvus is not running${NC}"
fi

echo -e "${BLUE}Checking gemini-proxy service...${NC}"
if systemctl is-active --quiet gemini-proxy; then
    echo -e "${GREEN}✓ gemini-proxy service is active${NC}"
else
    echo -e "${YELLOW}✗ gemini-proxy service is not active${NC}"
fi

echo -e "${BLUE}Listing MCP servers...${NC}"
claude mcp list

echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "\nMCP server 'code-indexer-${PROJECT_NAME}' configured with database: ${PROJECT_NAME}"
echo -e "\nTo index your codebase in Claude Code, use:"
echo -e "${YELLOW}Index the codebase at /path/to/your/${PROJECT_NAME}/project${NC}"
echo -e "\nTo search your code:"
echo -e "${YELLOW}Find specific functions${NC}"
echo -e "${YELLOW}Search for implementation details${NC}"
echo -e "\nTo add more projects, run this script again with a different project name:"
echo -e "${YELLOW}$0 project2${NC}"
