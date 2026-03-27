#!/usr/bin/env python3
"""
MCP Server for AI Stack VRAM Management

Provides tools for managing GPU VRAM allocation between STT and LLM services.
"""

import asyncio
import json
import sys
from typing import Optional

import httpx


class VRAMManager:
    """Manages VRAM allocation between STT and LLM."""

    def __init__(self):
        self.llama_cpp_base = "http://localhost:7865"
        self.whisper_base = "http://localhost:7861"
        self.timeout = httpx.Timeout(30.0)

    async def unload_llama_model(self) -> dict:
        """
        Unload the llama.cpp model from VRAM.

        Returns:
            dict: Status of the unload operation
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                # Method 1: POST /models/unload (llama.cpp router mode)
                response = await client.post(f"{self.llama_cpp_base}/models/unload")
                if response.status_code == 200:
                    return {"success": True, "method": "api", "message": "Model unloaded via API"}

                # Method 2: Check if endpoint exists
                if response.status_code == 404:
                    # Fallback: systemd stop
                    return await self._stop_llama_systemd()

                return {"success": False, "error": f"HTTP {response.status_code}", "body": response.text}

            except httpx.ConnectError as e:
                # llama.cpp not running, already unloaded
                return {"success": True, "method": "not_running", "message": "llama.cpp not running"}
            except Exception as e:
                return {"success": False, "error": str(e)}

    async def _stop_llama_systemd(self) -> dict:
        """Stop llama.cpp via systemd (fallback method)."""
        try:
            process = await asyncio.create_subprocess_exec(
                "systemctl", "--user", "stop", "llama-cpp",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()

            if process.returncode == 0:
                return {"success": True, "method": "systemd", "message": "Model unloaded via systemd"}
            else:
                return {"success": False, "error": stderr.decode()}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def load_llama_model(self) -> dict:
        """
        Load the llama.cpp model (trigger on next request).

        Returns:
            dict: Status of the load operation
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                # Trigger model load by calling health endpoint
                response = await client.get(f"{self.llama_cpp_base}/health")
                if response.status_code == 200:
                    return {"success": True, "message": "Model load triggered"}
                return {"success": False, "error": f"HTTP {response.status_code}"}
            except httpx.ConnectError:
                return {"success": False, "error": "llama.cpp not running"}
            except Exception as e:
                return {"success": False, "error": str(e)}

    async def get_vram_status(self) -> dict:
        """
        Get current VRAM usage.

        Returns:
            dict: VRAM status with used/free memory
        """
        try:
            process = await asyncio.create_subprocess_exec(
                "nvidia-smi",
                "--query-gpu=memory.used,memory.free,memory.total",
                "--format=csv,noheader,nounits",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()

            if process.returncode == 0:
                used, free, total = map(int, stdout.decode().strip().split(", "))
                return {
                    "success": True,
                    "used_mb": used,
                    "free_mb": free,
                    "total_mb": total,
                    "percent": round((used / total) * 100, 1) if total > 0 else 0
                }
            else:
                return {"success": False, "error": stderr.decode()}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def get_service_status(self) -> dict:
        """
        Get status of STT and LLM services.

        Returns:
            dict: Service status
        """
        status = {}

        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
            # Check Whisper STT
            try:
                response = await client.get(f"{self.whisper_base}/health")
                status["whisper_stt"] = {
                    "running": response.status_code == 200,
                    "status": "healthy" if response.status_code == 200 else "unhealthy"
                }
            except Exception as e:
                status["whisper_stt"] = {"running": False, "error": str(e)}

            # Check llama.cpp
            try:
                response = await client.get(f"{self.llama_cpp_base}/health")
                status["llama_cpp"] = {
                    "running": response.status_code == 200,
                    "status": "healthy" if response.status_code == 200 else "unhealthy"
                }
            except Exception as e:
                status["llama_cpp"] = {"running": False, "error": str(e)}

        return status


# MCP Protocol Implementation
manager = VRAMManager()


async def handle_tool(name: str, arguments: dict) -> dict:
    """Handle MCP tool calls."""
    if name == "unload_llama_model":
        result = await manager.unload_llama_model()
    elif name == "load_llama_model":
        result = await manager.load_llama_model()
    elif name == "get_vram_status":
        result = await manager.get_vram_status()
    elif name == "get_service_status":
        result = await manager.get_service_status()
    else:
        return {"error": f"Unknown tool: {name}"}

    return result


async def main():
    """MCP server main loop."""
    while True:
        try:
            line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
            if not line:
                break

            request = json.loads(line)
            if request.get("method") == "initialize":
                # Send initialization response
                response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id"),
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {
                                "unload_llama_model": "Unload llama.cpp model from VRAM",
                                "load_llama_model": "Load llama.cpp model (trigger on next request)",
                                "get_vram_status": "Get current GPU VRAM usage",
                                "get_service_status": "Get STT and LLM service status"
                            }
                        },
                        "serverInfo": {"name": "ai-stack-vram-manager", "version": "1.0.0"}
                    }
                }
                print(json.dumps(response), flush=True)
            elif request.get("method") == "tools/call":
                tool_name = request.get("params", {}).get("name")
                arguments = request.get("params", {}).get("arguments", {})
                result = await handle_tool(tool_name, arguments)

                response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id"),
                    "result": {
                        "content": [{"type": "text", "text": json.dumps(result, indent=2)}]
                    }
                }
                print(json.dumps(response), flush=True)

        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)}
            }
            print(json.dumps(error_response), flush=True)


if __name__ == "__main__":
    asyncio.run(main())
