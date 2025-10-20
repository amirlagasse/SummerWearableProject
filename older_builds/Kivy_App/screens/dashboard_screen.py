import asyncio
from kivy.uix.screenmanager import Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.progressbar import ProgressBar
from kivy.uix.scrollview import ScrollView
from kivy.graphics import Color, Rectangle, Ellipse
from kivy.uix.widget import Widget
from kivy.uix.anchorlayout import AnchorLayout
from kivy.clock import Clock
from kivy.uix.button import Button
from datetime import datetime

from ui.live_hr_graph import LiveHRGraph
from ble.hr_monitor import HRMonitor



class ConnectionStatus(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'horizontal'
        self.spacing = 6
        self.size_hint = (None, None)
        self.height = 40
        self.width = 300

        self.circle = Widget(size_hint=(None, None), size=(22, 22))
        with self.circle.canvas:
            Color(1, 0, 0, 1)
            self.circle_shape = Ellipse(pos=self.circle.pos, size=self.circle.size)
        self.circle.bind(pos=self.update_shape, size=self.update_shape)

        self.status_label = Label(
            text="Not Connected",
            font_size=32,
            color=(1, 1, 1, 1),
            size_hint=(None, None),
            size=(240, 40),
            halign="left",
            valign="middle"
        )
        self.status_label.bind(size=self.status_label.setter("text_size"))

        self.add_widget(self.circle)
        self.add_widget(self.status_label)

    def update_shape(self, *args):
        self.circle_shape.pos = self.circle.pos
        self.circle_shape.size = self.circle.size

    def set_status(self, status):
        self.circle.canvas.clear()
        if status == "connected":
            self.status_label.text = "Connected"
            with self.circle.canvas:
                Color(0, 1, 0, 1)
                self.circle_shape = Ellipse(pos=self.circle.pos, size=self.circle.size)
        elif status == "connecting":
            self.status_label.text = "Connecting..."
            with self.circle.canvas:
                Color(1, 1, 0, 1)
                self.circle_shape = Ellipse(pos=self.circle.pos, size=self.circle.size)
        else:
            self.status_label.text = "Not Connected"
            with self.circle.canvas:
                Color(1, 0, 0, 1)
                self.circle_shape = Ellipse(pos=self.circle.pos, size=self.circle.size)


class DailyDashboard(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = "vertical"
        self.padding = 10
        self.spacing = 10

        with self.canvas.before:
            Color(0.2, 0.2, 0.2, 1)
            self.bg_rect = Rectangle(pos=self.pos, size=self.size)
        self.bind(pos=self.update_bg, size=self.update_bg)

        self.device_label = Label(
            text="No device selected",
            font_size=36,
            size_hint=(1, None),
            height=40,
            color=(1, 1, 1, 1)
        )
        self.add_widget(self.device_label)

        wearable_container = BoxLayout(size_hint=(1, None), height=300, orientation="vertical")

        wearable_image = Image(source="assets/wearable.png", size_hint=(None, None), size=(240, 240))
        image_container = AnchorLayout(anchor_x="center", anchor_y="top", size_hint=(1, None), height=215)
        image_container.add_widget(wearable_image)
        wearable_container.add_widget(image_container)

        self.connection = ConnectionStatus()
        status_container = AnchorLayout(anchor_x="center", anchor_y="top", size_hint=(1, None), height=50)
        status_container.add_widget(self.connection)
        wearable_container.add_widget(status_container)

        self.connect_button = Button(text="Connect", size_hint=(None, None), size=(160, 40))
        self.connect_button.bind(on_press=self.start_connection)
        button_container = AnchorLayout(anchor_x="center", anchor_y="top", size_hint=(1, None), height=60)
        button_container.add_widget(self.connect_button)
        wearable_container.add_widget(button_container)

        self.add_widget(wearable_container)

        scroll = ScrollView(size_hint=(1, 1))
        self.content = BoxLayout(orientation="vertical", size_hint_y=None, spacing=10, padding=10)
        self.content.bind(minimum_height=self.content.setter("height"))

        for label_text, value in [("Readiness", 0.8), ("Sleep", 0.6), ("Vitality", 0.7)]:
            bar_container = BoxLayout(orientation="vertical", size_hint_y=None, height=60)
            label = Label(text=f"{label_text}: {int(value * 100)}%", size_hint_y=None, height=20, color=(1, 1, 1, 1))
            pb = ProgressBar(value=value * 100, max=100, size_hint_y=None, height=20)
            bar_container.add_widget(label)
            bar_container.add_widget(pb)
            self.content.add_widget(bar_container)

        self.content.add_widget(Label(text="Sleep History", size_hint_y=None, height=30, color=(1, 1, 1, 1)))
        self.content.add_widget(Image(source="assets/sleep_graph.png", size_hint_y=None, height=200))

        self.content.add_widget(Label(text="Live Heart Rate", size_hint_y=None, height=30, color=(1, 1, 1, 1)))
        self.hr_graph = LiveHRGraph()
        self.hr_graph.size_hint_y = None
        self.hr_graph.height = 300
        self.content.add_widget(self.hr_graph)

        scroll.add_widget(self.content)
        self.add_widget(scroll)

        self.hr_monitor = HRMonitor(on_hr_callback=self._handle_hr)
        HRMonitor.register_device_update_callback(self.update_device_label)
        self.update_device_label()

    def update_bg(self, *args):
        self.bg_rect.pos = self.pos
        self.bg_rect.size = self.size

    def update_device_label(self, *args):
        selected = HRMonitor._selected_address
        name = HRMonitor._selected_name
        if selected and name:
            display = f"Selected Device ({name}: {selected[:4]})"
        elif selected:
            display = f"Selected Device (Unknown: {selected[:4]})"
        else:
            display = "No device selected"
        self.device_label.text = display




    def start_connection(self, instance):
        self.connection.set_status("connecting")
        loop = asyncio.get_event_loop()
        loop.create_task(self.connect_hr_monitor())

    async def connect_hr_monitor(self):
        connected = await self.hr_monitor.connect()
        if connected:
            self.connection.set_status("connected")
        else:
            self.connection.set_status("disconnected")


    def _handle_hr(self, bpm):
        self.hr_graph.add_point(bpm)
        self.log_heart_rate(bpm)

    def log_heart_rate(self, bpm):
        from datetime import datetime
        timestamp = datetime.now()
        date_str = timestamp.date().isoformat()  # e.g., 2025-07-20
        log_path = f"data/hr_log_{date_str}.csv"

        try:
            with open(log_path, "a") as f:
                f.write(f"{timestamp.isoformat()},{bpm}\n")
        except Exception as e:
            print(f"[ERROR] Could not log HR: {e}")




class DashboardScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.dashboard = DailyDashboard()
        self.add_widget(self.dashboard)

    def on_pre_enter(self, *args):
        self.dashboard.update_device_label()
