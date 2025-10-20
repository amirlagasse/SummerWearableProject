import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.clock import Clock
from kivy_garden.graph import Graph, LinePlot
from datetime import datetime
import asyncio
from ble.hr_monitor import HRMonitor

class LiveHRGraph(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 10
        self.window_seconds = 60
        self.hr_data = []

        axis_label = Label(
            size_hint_y=None,
            height=20,
            font_size='12sp',
            bold=True,
            halign='center',
            valign='middle'
        )
        axis_label.bind(size=axis_label.setter('text_size'))
        self.add_widget(axis_label)

        self.graph = Graph(
            xlabel='Time (s)',
            ylabel='30     BPM     230',
            x_ticks_major=10,
            y_ticks_major=20,
            y_grid_label=True,
            x_grid_label=True,
            padding=5,
            x_grid=True,
            y_grid=True,
            xmin=-self.window_seconds,
            xmax=0,
            ymin=30,
            ymax=250,
            size_hint_y=None,
            height=320,
            draw_border=True,
            border_color=[0.6, 0.6, 0.6, 1]
        )

        self.plot = LinePlot(line_width=1.5, color=[1, 0, 0, 1])
        self.graph.add_plot(self.plot)
        self.add_widget(self.graph)

        Clock.schedule_interval(self.update_graph, 1)

    def add_point(self, bpm):
        if bpm <= 0:
            return
        now = datetime.now().timestamp()
        self.hr_data.append((now, bpm))

    def update_graph(self, dt):
        now_timestamp = datetime.now().timestamp()
        cutoff = now_timestamp - self.window_seconds
        self.hr_data = [(t, bpm) for (t, bpm) in self.hr_data if t >= cutoff]
        shifted_points = [(t - now_timestamp, bpm) for (t, bpm) in self.hr_data]
        self.plot.points = shifted_points
        self.graph.xlabel = f"Time (s) — now: {datetime.now().strftime('%H:%M:%S')}"
