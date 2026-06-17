
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

    url = f"{WS_BASE}/ws/equipments"
    print(f"{ts()} Connecting to {url} ...")

    async with websockets.connect(url) as ws:
        print(f"{ts()} Connected. Waiting for equipments_list ...")
        async for raw in ws:
            event = json.loads(raw)
            print_event(event)
            if event.get("event") == "equipments_list":
                equipments = event.get("equipments", [])
                print(f"\n{ts()} {len(equipments)} equipment(s) known:")
                for eq in equipments:
                    print(f"   {eq['asset_uuid']}  vars={list(eq.get('variables', {}).keys())}")
                break
    print(f"\n{ts()} Done.")


async def stream_equipment(asset_uuid: str, simulate: bool = False, drop: bool = False):
    url = f"{WS_BASE}/ws/equipments/{asset_uuid}"
    print(f"{ts()} Connecting to {url} ...")

    got_first_update = False

    async with websockets.connect(url) as ws:
        print(f"{ts()} Connected. Streaming {asset_uuid}\n")

        async for raw in ws:
            event = json.loads(raw)
            print_event(event)

            if event.get("event") == "equipment_update" and not got_first_update:
                got_first_update = True

                if simulate:
                    msg = {
                        "method": "simulation_mode",
                        "params": {"name": "simulationMode", "args": True}
                    }
                    print(f"\n{ts()} → [simulation_mode] sending ...")
                    await ws.send(json.dumps(msg))

                if drop:
                    msg = {"method": "drop_connection", "params": {}}
                    print(f"\n{ts()} → [drop_connection] sending ...")
                    await ws.send(json.dumps(msg))

            if event.get("event") == "connection_dropped":
                print(f"\n{ts()} Connection dropped by server. Exiting.")
                break

            if event.get("event") == "error":
                print(f"\n{ts()} Server error: {event.get('message')}")
                break

async def main():
    parser = argparse.ArgumentParser(description="Test openfactory-equipment-api WebSocket endpoints.")
    parser.add_argument("asset_uuid", nargs="?", help="Asset UUID to stream (omit to list all equipments)")
    parser.add_argument("--simulate", action="store_true", help="Toggle simulation mode after first update")
    parser.add_argument("--drop", action="store_true", help="Send drop_connection after first update")
    parser.add_argument("--host", default=API_HOST, help=f"API hostname (default: {API_HOST})")
    args = parser.parse_args()

    global WS_BASE
    WS_BASE = f"ws://{args.host}"

    try:
        if args.asset_uuid:
            await stream_equipment(args.asset_uuid, simulate=args.simulate, drop=args.drop)
        else:
            await list_equipments()
    except KeyboardInterrupt:
        print(f"\n{ts()} Interrupted.")
    except Exception as e:
        print(f"\n{ts()} Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())