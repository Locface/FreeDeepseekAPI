FROM docker.io/library/node:22-alpine

# ---------- Runtime defaults ----------
# Auth can be supplied in three ways (no image rebuild required):
#   1. Single file via volume:   -v /host/deepseek-auth.json:/data/auth/deepseek-auth.json:ro
#      and DEEPSEEK_AUTH_DIR=/data/auth   (default, picks up all *.json in the dir)
#   2. Multi-account dir:        -v /host/accounts/:/data/auth/:ro
#      All *.json files are loaded as separate accounts (round-robin + auto-cooldown).
#   3. Docker secrets (Swarm):   DEEPSEEK_AUTH_PATH=/run/secrets/deepseek-auth.json
#
# To update credentials: replace the file on the host and send SIGHUP to reload,
# or restart the container — no image rebuild needed.
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=9655 \
    NON_INTERACTIVE=1 \
    DEEPSEEK_AUTH_DIR=/data/auth \
    PROXY_API_KEY_FILE=/run/secrets/proxy-api-key

WORKDIR /app

# No npm dependencies — copy only what the proxy needs at runtime.
COPY --chown=1000:1000 package.json server.js ./
COPY --chown=1000:1000 lib/pow.js ./lib/pow.js

# Create auth data dir with correct ownership before switching user
RUN mkdir -p /data/auth && chown -R 1000:1000 /data

USER 1000:1000

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["node", "-e", "const http=require('http');const req=http.get({host:'127.0.0.1',port:process.env.PORT||9655,path:'/health'},res=>{res.resume();process.exit(res.statusCode===200?0:1)});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1)})"]

CMD ["node", "server.js"]
