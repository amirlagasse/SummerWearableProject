import asyncio
from kivy.uix.screenmanager import Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.scrollview import ScrollView
from kivy.uix.popup import Popup
from kivy.uix.gridlayout import GridLayout
from kivy.graphics import Color, Rectangle
from kivy.clock import Clock
from bleak import BleakScanner

from ble.hr_monitor import HRMonitor


class SettingsTab(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.spacing = 10
        self.padding = 10
        self.size_hint_y = None
        self.bind(minimum_height=self.setter('height'))

        with self.canvas.before:
            Color(0.2, 0.2, 0.2, 1)
            self.bg = Rectangle(pos=self.pos, size=self.size)
        self.bind(pos=self._update_bg, size=self._update_bg)

        self.add_widget(self.create_toggle_section("Workout Colors", self.create_workout_colors_section()))
        self.add_widget(self.create_toggle_section("SETTINGS 1", self.create_placeholder_section("SETTINGS 1")))
        self.add_widget(self.create_toggle_section("Device Selector", self.create_device_scan_section()))
        self.add_widget(self.create_toggle_section("SETTINGS 3", self.create_placeholder_section("SETTINGS 3")))

    def _update_bg(self, *args):
        self.bg.pos = self.pos
        self.bg.size = self.size

    def create_toggle_section(self, title, content_widget):
        section = BoxLayout(orientation='vertical', size_hint_y=None, spacing=5)
        section.bind(minimum_height=section.setter('height'))

        toggle_row = BoxLayout(orientation='horizontal', size_hint_y=None, height=40, padding=[10, 0, 10, 0])
        with toggle_row.canvas.before:
            Color(0.4, 0.4, 0.4, 1)
            toggle_row.bg_rect = Rectangle(pos=toggle_row.pos, size=toggle_row.size)
        toggle_row.bind(pos=lambda inst, val: setattr(toggle_row.bg_rect, 'pos', val))
        toggle_row.bind(size=lambda inst, val: setattr(toggle_row.bg_rect, 'size', val))

        title_label = Label(text=title, size_hint_x=0.9, halign='left', valign='middle', color=(1, 1, 1, 1))
        title_label.bind(size=title_label.setter('text_size'))

        arrow_label = Label(text='▶️', font_size=40, font_name='fonts/NotoEmoji-Regular.ttf',
                            size_hint_x=0.1, halign='right', valign='middle')
        arrow_label.bind(size=arrow_label.setter('text_size'))

        toggle_row.add_widget(title_label)
        toggle_row.add_widget(arrow_label)
        section.add_widget(toggle_row)

        content_shown = [False]

        def toggle(*args):
            if content_shown[0]:
                section.remove_widget(content_widget)
                arrow_label.text = "▶️"
            else:
                section.add_widget(content_widget)
                arrow_label.text = "🔽"
                if hasattr(content_widget, 'on_expand'):
                    content_widget.on_expand()
            content_shown[0] = not content_shown[0]

        toggle_row.bind(on_touch_down=lambda inst, touch: toggle() if toggle_row.collide_point(*touch.pos) else None)

        return section

    def create_workout_colors_section(self):
        layout = BoxLayout(orientation='vertical', spacing=10, padding=[10, 0, 10, 0], size_hint_y=None)
        layout.bind(minimum_height=layout.setter('height'))

        workouts = ['Bike', 'Run', 'Row', 'Lift', 'Yoga', 'Swim', 'Walk', 'Stretch', 'HIIT', 'Other']
        for w in workouts:
            row = BoxLayout(orientation='horizontal', size_hint_y=None, height=40)
            label = Label(text=w, size_hint_x=0.7, color=(1, 1, 1, 1))
            color_btn = Button(size_hint_x=0.3, background_color=(0.7, 0.7, 0.7, 1))
            color_btn.bind(on_release=lambda btn, wtype=w: SettingsScreen.open_color_selection(wtype, btn))
            row.add_widget(label)
            row.add_widget(color_btn)
            layout.add_widget(row)

        return layout

    def create_placeholder_section(self, title):
        layout = BoxLayout(orientation='vertical', spacing=5, padding=[10, 0, 10, 0], size_hint_y=None)
        layout.bind(minimum_height=layout.setter('height'))

        for i in range(3):
            row = Label(text=f"{title} content {i + 1}", size_hint_y=None, height=30, color=(1, 1, 1, 1))
            layout.add_widget(row)

        return layout

    def create_device_scan_section(self):
        container = BoxLayout(orientation='vertical', spacing=10, size_hint_y=None)
        container.bind(minimum_height=container.setter('height'))
        container.devices = []

        label = Label(text="Tap below to scan and select", color=(1, 1, 1, 1), size_hint_y=None, height=30)
        container.add_widget(label)

        device_box = BoxLayout(orientation='vertical', spacing=5, size_hint_y=None)
        device_box.bind(minimum_height=device_box.setter('height'))
        container.add_widget(device_box)

        def on_expand():
            device_box.clear_widgets()
            asyncio.ensure_future(scan_and_display(device_box, container))

        async def scan_and_display(box, container_ref):
            label.text = "Scanning..."
            devices = await BleakScanner.discover(timeout=5)
            found_named = [d for d in devices if d.name][:5]

            container_ref.devices = found_named
            label.text = "Select a device below"

            for d in found_named:
                btn = Button(text=f"{d.name} ({d.address})", size_hint_y=None, height=40)
                btn.bind(on_release=lambda btn, name=d.name, addr=d.address: connect_and_save(name, addr))
                box.add_widget(btn)

        def connect_and_save(name, address):
            HRMonitor.set_device(address, name)
            label.text = f"{name} Device Address Set"
            print(f"[SETTINGS] Saved: {name} ({address})")

        container.on_expand = on_expand
        return container

class SettingsScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        root_layout = BoxLayout(orientation='vertical')
        scroll = ScrollView()
        tab = SettingsTab()
        scroll.add_widget(tab)
        root_layout.add_widget(scroll)
        self.add_widget(root_layout)

    @staticmethod
    def open_color_selection(workout_type, current_button):
        colors = {
            'Red': (1, 0, 0, 1),
            'Green': (0, 1, 0, 1),
            'Blue': (0, 0, 1, 1),
            'Yellow': (1, 1, 0, 1),
            'Magenta': (1, 0, 1, 1),
            'Cyan': (0, 1, 1, 1),
            'Orange': (1, 0.5, 0, 1),
            'White': (1, 1, 1, 1),
            'Black': (0, 0, 0, 1),
            'Lime': (0.7, 1, 0, 1)
        }

        layout = GridLayout(cols=5, padding=10, spacing=10)
        for name, rgba in colors.items():
            btn = Button(background_color=rgba, size_hint=(None, None), size=(40, 40))

            def set_color(instance, color=rgba):
                current_button.background_color = color
                print(f"{workout_type} color set to: {color}")
                popup.dismiss()

            btn.bind(on_release=set_color)
            layout.add_widget(btn)

        popup = Popup(title=f"Choose color for {workout_type}", content=layout, size_hint=(0.8, 0.4))
        popup.open()