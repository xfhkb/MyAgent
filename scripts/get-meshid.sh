#!/bin/bash
# Get MeshID from MeshCentral server automatically
# Uses meshctrl.js to list device groups

SERVER_IP="85.158.110.250"
SERVER_PORT="8080"
SSH_PORT="56777"
SSH_PASS="ujhjl100%"
SSH_USER="root"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[*] Getting MeshID from MeshCentral server${NC}"

# Get list of device groups using meshctrl
echo -e "${YELLOW}[*] Connecting to server...${NC}"
RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SERVER_IP \
  "cd /opt/meshcentral/node_modules/meshcentral && node meshctrl.js ListDeviceGroups --url wss://localhost:$SERVER_PORT --loginuser admin --loginpass admin 2>/dev/null" 2>/dev/null)

if [ -z "$RESULT" ]; then
    echo -e "${RED}[!] Failed to get device groups. Trying with password prompt...${NC}"
    echo -e "${YELLOW}[*] Please enter MeshCentral admin password:${NC}"
    read -s ADMIN_PASS
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SERVER_IP \
      "cd /opt/meshcentral/node_modules/meshcentral && node meshctrl.js ListDeviceGroups --url wss://localhost:$SERVER_PORT --loginuser admin --loginpass '$ADMIN_PASS' 2>/dev/null" 2>/dev/null)
fi

if [ -z "$RESULT" ]; then
    echo -e "${RED}[!] Failed to get device groups${NC}"
    echo -e "${YELLOW}[*] Trying alternative method...${NC}"
    
    # Try to get from database directly
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SERVER_IP \
      "cd /opt/meshcentral/meshcentral-data && node -e \"
        const Datastore = require('nedb');
        const db = new Datastore({ filename: 'meshcentral.db', autoload: true });
        db.find({ type: 'mesh' }, function(err, docs) {
          if (docs) {
            docs.forEach(function(mesh) {
              console.log(mesh.name + ' | ' + mesh._id + ' | ' + mesh.mtype);
            });
          }
        });
      \"" 2>/dev/null)
fi

if [ -z "$RESULT" ]; then
    echo -e "${RED}[!] All methods failed${NC}"
    echo -e "${YELLOW}[*] Please get MeshID manually:${NC}"
    echo "  1. Open web UI: http://$SERVER_IP:$SERVER_PORT"
    echo "  2. Go to Device Groups"
    echo "  3. Select a group"
    echo "  4. Click 'Add Agent'"
    echo "  5. Copy MeshID (0x...)"
    exit 1
fi

echo -e "${GREEN}[+] Device Groups:${NC}"
echo "$RESULT"
echo ""

# Parse and show MeshID
echo -e "${YELLOW}[*] Available MeshIDs:${NC}"
echo "$RESULT" | while IFS='|' read -r name id type; do
    name=$(echo "$name" | xargs)
    id=$(echo "$id" | xargs)
    type=$(echo "$type" | xargs)
    
    # Convert to hex format if needed
    if [[ ! "$id" == 0x* ]]; then
        hex_id=$(echo "$id" | base64 -d 2>/dev/null | xxd -p | tr 'a-f' 'A-F' | tr -d '\n')
        if [ -n "$hex_id" ]; then
            echo -e "  ${GREEN}$name${NC}: 0x$hex_id (type: $type)"
        else
            echo -e "  ${GREEN}$name${NC}: $id (type: $type)"
        fi
    else
        echo -e "  ${GREEN}$name${NC}: $id (type: $type)"
    fi
done

echo ""
echo -e "${YELLOW}[*] Use one of these MeshIDs in the installer${NC}"
