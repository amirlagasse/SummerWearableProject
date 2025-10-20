from kivy.uix.screenmanager import Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.anchorlayout import AnchorLayout
from kivy.graphics import Color, Rectangle
from kivy.garden.graph import Graph, LinePlot
from datetime import datetime, date
import os

class MetricsScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        self._add_background(self.layout)

        # Graph Setup (Top)
        self.hr_graph = Graph(
            xlabel='Time',
            ylabel='HR',
            x_ticks_minor=5,
            x_ticks_major=10,
            y_ticks_major=10,
            y_grid_label=True,
            x_grid_label=False,
            padding=5,
            x_grid=True,
            y_grid=True,
            xmin=0,
            xmax=60,
            ymin=40,
            ymax=180,
            size_hint_y=None,
            height=300
        )

        self.layout.add_widget(self.hr_graph)

        # Info Labels
        self.metric_labels = []
        for _ in range(5):
            lbl = Label(color=(1, 1, 1, 1), size_hint_y=None, height=30)
            self.metric_labels.append(lbl)
            self.layout.add_widget(lbl)

        # Refresh Button
        self.refresh_button_container = AnchorLayout(anchor_x='center', anchor_y='bottom', size_hint=(1, None), height=60)
        self.refresh_button = Button(text="Refresh", size_hint=(None, None), size=(160, 40))
        self.refresh_button.bind(on_press=lambda x: self.update_metrics())
        self.refresh_button_container.add_widget(self.refresh_button)

        self.layout.add_widget(self.refresh_button_container)
        self.add_widget(self.layout)

        self.update_metrics()

    def _add_background(self, layout):
        with layout.canvas.before:
            Color(0.15, 0.15, 0.15, 1)
            self.bg = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

    def _update_bg(self, instance, value):
        self.bg.pos = instance.pos
        self.bg.size = instance.size

    def update_metrics(self):
        log_path = f"data/hr_log_{date.today().isoformat()}.csv"
        if not os.path.exists(log_path):
            print("No heart rate log found.")
            return

        bpm_values = []
        with open(log_path, "r") as f:
            for line in f:
                try:
                    timestamp_str, bpm_str = line.strip().split(",")
                    bpm = int(bpm_str)
                    timestamp = datetime.fromisoformat(timestamp_str)
                    bpm_values.append((timestamp, bpm))
                except:
                    continue

        if not bpm_values:
            print("No valid heart rate data.")
            return

        for p in self.hr_graph.plots[:]:
            self.hr_graph.remove_plot(p)

        # Split into segments with no large time gaps
        segments = []
        current_segment = []
        last_time = None
        max_gap = 30  # seconds

        for i, (t, bpm) in enumerate(bpm_values):
            if last_time is not None and (t - last_time).total_seconds() > max_gap:
                if current_segment:
                    segments.append(current_segment)
                    current_segment = []
            seconds_since_start = (t - bpm_values[0][0]).total_seconds()
            current_segment.append((seconds_since_start, bpm))

            last_time = t

        if current_segment:
            segments.append(current_segment)

        # Add new plots
        for segment in segments:
            plot = LinePlot(line_width=1.5, color=(1, 0.3, 0.3, 1))
            plot.points = segment
            self.hr_graph.add_plot(plot)

        raw_bpms = [b for _, b in bpm_values]
        avg_bpm = sum(raw_bpms) / len(raw_bpms)
        max_bpm = max(raw_bpms)
        resting_bpm = min(raw_bpms)
        high_bpm_threshold = 130
        high_bpm_count = sum(1 for b in raw_bpms if b > high_bpm_threshold)

        self.hr_graph.xmax = max(segment[-1][0] for segment in segments if segment)
        self.hr_graph.ymax = max(100, max(raw_bpms) + 10)
        self.hr_graph.ymin = min(40, min(raw_bpms) - 10)

        # Update visible metric labels
        metric_texts = [
            f"Total readings: {len(raw_bpms)}",
            f"Average HR: {avg_bpm:.1f} BPM",
            f"Max HR: {max_bpm} BPM",
            f"Resting HR (min): {resting_bpm} BPM",
            f"Training Load (HR > {high_bpm_threshold}): {high_bpm_count} points"
        ]
        for label, text in zip(self.metric_labels, metric_texts):
            label.text = text
