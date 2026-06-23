#!/bin/bash
# MeshAgent .msh file generator
# Generates .msh configuration file for MeshAgent

SERVER_IP="85.158.110.250"
SERVER_PORT="8080"
AGENT_PORT="1234"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[*] MeshAgent .msh Generator${NC}"

# Get MeshID from user
echo -e "${YELLOW}[*] Getting MeshID from server...${NC}"
echo -e "${YELLOW}[*] Go to MeshCentral web UI → Device Groups → Select group → Click 'Add Agent' → Copy MeshID${NC}"
read -p "Enter MeshID (0x...): " MESH_ID

if [ -z "$MESH_ID" ]; then
    echo -e "${RED}[!] MeshID is required${NC}"
    exit 1
fi

# Get ServerID from certificate
echo -e "${YELLOW}[*] Getting ServerID from certificate...${NC}"
SERVER_ID=$(sshpass -p 'ujhjl100%' ssh -o StrictHostKeyChecking=no -p 56777 root@85.158.110.250 "openssl x509 -in /opt/meshcentral/meshcentral-data/agentserver-cert-public.crt -noout -fingerprint -sha384 2>/dev/null | cut -d'=' -f2 | tr -d ':' | tr 'a-f' 'A-F'" 2>/dev/null)

if [ -z "$SERVER_ID" ]; then
    echo -e "${RED}[!] Failed to get ServerID from certificate${NC}"
    exit 1
fi

echo -e "${GREEN}[+] ServerID: $SERVER_ID${NC}"

# Get MeshName
read -p "Enter MeshName (default: MyComputers): " MESH_NAME
MESH_NAME=${MESH_NAME:-MyComputers}

# Get MeshType
echo -e "${YELLOW}[*] MeshType:${NC}"
echo "  1 = LAN"
echo "  2 = WAN"
echo "  3 = Local"
read -p "Enter MeshType (default: 2): " MESH_TYPE
MESH_TYPE=${MESH_TYPE:-2}

# Determine agent port
if [ -n "$AGENT_PORT" ]; then
    PORT=$AGENT_PORT
else
    PORT=$SERVER_PORT
fi

# Generate .msh file
MSH_FILE="meshagent.msh"
cat > "$MSH_FILE" << EOF

MeshName=$MESH_NAME
MeshType=$MESH_TYPE
MeshID=$MESH_ID
ServerID=$SERVER_ID
MeshServer=wss://$SERVER_IP:$PORT/agent.ashx
EOF

echo -e "${GREEN}[+] .msh file generated: $MSH_FILE${NC}"
echo -e "${YELLOW}[*] Contents:${NC}"
cat "$MSH_FILE"

echo ""
echo -e "${GREEN}[*] To use:${NC}"
echo "  1. Place .msh file next to MeshService.exe"
echo "  2. Run: MeshService.exe -fullinstall"
echo "  3. Or embed into exe: MeshService.exe --copy-msh=\"1\" -fullinstall"
