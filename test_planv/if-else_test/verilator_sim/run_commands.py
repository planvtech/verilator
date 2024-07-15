import os
"""
def run_command(command):
    try:
        print(f"Running command: {command}")
        result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(result.stdout.decode())
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}")
        print(e.stderr.decode())
        raise
"""
def main():
    commands = [
        "cd /home/yilou/Desktop/OSVISE/Randomization_Enable_4_Verilator-planV-/verilator_planv && ./configure && make",
        "make clean",
        "make json_dump=1 debug=1"
    ]

    for command in commands:
        print(f"**************************\nRunning command: {command}\n**************************")
        os.system(command)

if __name__ == '__main__':
    main() 