import subprocess
import time

def main():
    processes = []
    try:
        print(" [1/3] Starting virtual cnc device+adapter...")
        adapter_proc = subprocess.Popen(["python", "scripts/run_virtual_adapters.py", "cnc"])
        processes.append(adapter_proc)
        
        time.sleep(10)

        print("\n [2/3] Bringing up OPC-UA device (lab-usine/plt-3013/cnc.yml)...")
        device_proc = subprocess.Popen(["ofa", "device", "up", "lab-usine/plt-3013/cnc.yml"])
        processes.append(device_proc)
        
        time.sleep(15)

        print("\n [3/3] Bringing up equipments API...")
        # api_proc = subprocess.Popen(["ofa", "apps", "up", "api.yml"])
        # processes.append(api_proc)

        print("\n Entire CNC virtual setup is up and running!")
        print("Press Ctrl+C to tear down the entire stack safely.")
        
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n\n Tearing down entire CNC virtual setup...")
        
        for proc in processes:
            if proc.poll() is None:
                print(f"Terminating process PID {proc.pid}...")
                proc.terminate()
        
        time.sleep(2)
        print("Cleanup complete.")

if __name__ == "__main__":
    main()