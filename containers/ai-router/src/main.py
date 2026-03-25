import os
import yaml
import logging
from typing import Dict, Any

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
import httpx

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-router")

app = FastAPI(title="ai-router", version="1.0.0")

# Load configuration
CONFIG_PATH = os.environ.get("ROUTER_CONFIG", "config/models.yaml")
with open(CONFIG_PATH, "r") as f:
    config = yaml.safe_load(f)

ENDPOINTS = config.get("endpoints", {})
MODELS = config.get("models", {})

http_client = httpx.AsyncClient(timeout=120.0)

@app.on_event("shutdown")
async def shutdown_event():
    await http_client.aclose()

@app.get("/v1/models")
async def list_models():
    data = []
    for model_name in MODELS.keys():
        data.append({
            "id": model_name,
            "object": "model",
            "created": 1677610602,
            "owned_by": "ai-router"
        })
    return {"object": "list", "data": data}

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    model_name = body.get("model")

    if not model_name or model_name not in MODELS:
        raise HTTPException(status_code=404, detail=f"Model {model_name} not found in router config")

    fallback_chain = MODELS[model_name]
    is_stream = body.get("stream", False)

    for attempt, route in enumerate(fallback_chain):
        endpoint_id = route.get("endpoint")
        upstream_model = route.get("upstream_model")
        
        endpoint_info = ENDPOINTS.get(endpoint_id)
        if not endpoint_info:
            logger.error(f"Endpoint {endpoint_id} not defined in config")
            continue

        base_url = endpoint_info["base_url"].rstrip("/")
        api_key_env = endpoint_info.get("api_key_env")
        api_key = os.environ.get(api_key_env, "") if api_key_env else ""
        
        # Modify the body model to match what the upstream provider expects
        body["model"] = upstream_model
        
        headers = {
            "Content-Type": "application/json"
        }
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        target_url = f"{base_url}/chat/completions"
        logger.info(f"Routing request to {endpoint_id} ({upstream_model}) at {target_url}")

        try:
            req = http_client.build_request("POST", target_url, headers=headers, json=body)
            response = await http_client.send(req, stream=is_stream)

            if response.status_code == 429:
                logger.warning(f"[429 Quota] Endpoint {endpoint_id} returned Too Many Requests. Falling back...")
                continue
            
            if response.status_code != 200:
                body_resp = await response.aread() if not is_stream else b""
                logger.error(f"Endpoint {endpoint_id} failed with status {response.status_code}. Response: {body_resp}")
                # Fallback purely on 500s or 429. For 4xx (like 400 bad request, 401 auth), fail early or log and try fallback.
                if response.status_code >= 500:
                    continue
                if not is_stream:
                    return JSONResponse(status_code=response.status_code, content=response.json())

            if is_stream:
                async def stream_generator():
                    async for chunk in response.aiter_bytes():
                        yield chunk
                # Re-issue headers safely
                out_headers = {k: v for k, v in response.headers.items() if k.lower() not in ("content-length", "content-encoding")}
                return StreamingResponse(stream_generator(), media_type="text/event-stream", headers=out_headers)
            else:
                return JSONResponse(status_code=response.status_code, content=response.json())

        except httpx.ConnectError:
            logger.warning(f"Failed to connect to {endpoint_id} at {target_url} (Likely due to STT VRAM override or network error). Falling back...")
            continue
        except httpx.TimeoutException:
            logger.warning(f"Timeout communicating with {endpoint_id}. Falling back...")
            continue
        except Exception as e:
            logger.error(f"Unexpected proxy error via {endpoint_id}: {str(e)}")
            continue

    raise HTTPException(status_code=503, detail="All endpoints in backup chain failed or timed out.")
