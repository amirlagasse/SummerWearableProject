# utils/graph_utils.py

from matplotlib import pyplot as plt

def save_sleep_graph():
    sleep_data = [6.5, 7.2, 5.8, 8.0, 6.9, 7.5, 7.0]
    nights = list(range(1, len(sleep_data) + 1))
    plt.figure(figsize=(4, 2))
    plt.plot(nights, sleep_data, color='deepskyblue', marker='o')
    plt.title('Sleep Duration (Past 7 Nights)')
    plt.xlabel('Night')
    plt.ylabel('Hours')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig('assets/sleep_graph.png')
    plt.close()
