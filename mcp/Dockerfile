FROM node:20-alpine

RUN npm install -g @modelcontextprotocol/server-memory mcp-proxy

RUN mkdir -p /data && echo '{"entities":[],"relations":[]}' > /data/memory.json

ENV MEMORY_FILE_PATH=/data/memory.json

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8000/mcp || exit 1

CMD ["mcp-proxy", "--port", "8000", "--allow-origin", "*", \
     "--", "npx", "-y", "@modelcontextprotocol/server-memory"]
