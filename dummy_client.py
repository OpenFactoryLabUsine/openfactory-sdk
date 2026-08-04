import asyncio
import json
import argparse
import websockets
import sys
from datetime import datetime

API_HOST = "localhost/equipments-api"
WS_BASE = f"ws://{API_HOST}"

def ts():
    return datetime.now().strftime("%H:%M:%S")

def pretty(event: dict):
    return json.dumps(event, indent=2, ensure_ascii=False)

def print_event(event: dict, prefix: str = "←"):
    kind = event.get("event", "?")
    print(f"\n{ts()} {prefix} [{kind}]")
    print(pretty(event))

async def list_equipments():
    url = f"{WS_BASE}/equipments"
    print(f"{ts()} Connecting to {url} ...")

    async with websockets.connect(url) as ws:
        async for raw in ws:
            event = json.loads(raw)
            print_event(event)
            if event.get("event") == "equipments_list":
                break

async def stream_equipment(asset_uuid: str, method: str = None, params: str = None):
    url = f"{WS_BASE}/equipments/{asset_uuid}"
    print(f"{ts()} Connecting to {url} ...")

    async with websockets.connect(url) as ws:
        print(f"{ts()} Connected. Streaming {asset_uuid}\n")

        if method:
            payload = {"method": method, "params": json.loads(params) if params else {}}
            print(f"\n{ts()} → [{method}] sending {json.dumps(payload)} ...")
            await ws.send(json.dumps(payload))

        async for raw in ws:
            event = json.loads(raw)
            print_event(event)

            if event.get("event") in ["connection_dropped", "error"]:
                break

async def main():
    parser = argparse.ArgumentParser(description="Test openfactory-equipment-api WebSocket endpoints.")
    parser.add_argument("asset_uuid", nargs="?", help="Asset UUID to stream")
    parser.add_argument("--host", default=API_HOST, help=f"API hostname")
    parser.add_argument("--method", help="Method to call (e.g., simulation_mode)")
    parser.add_argument("--params", help="JSON string of parameters (e.g., '{\"name\": \"simulationMode\", \"args\": true}')")
    
    args = parser.parse_args()
    global WS_BASE
    WS_BASE = f"ws://{args.host}"

    try:
        if args.asset_uuid:
            await stream_equipment(args.asset_uuid, method=args.method, params=args.params)
        else:
            await list_equipments()
    except KeyboardInterrupt:
        print(f"\n{ts()} Interrupted.")
    except Exception as e:
        print(f"\n{ts()} Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())