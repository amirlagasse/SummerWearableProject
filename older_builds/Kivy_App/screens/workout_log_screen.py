# screens/workout_log_screen.py
from kivy.uix.screenmanager import Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.scrollview import ScrollView
from kivy.uix.label import Label
from kivy.graphics import Color, Rectangle

class WorkoutLogTab(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.spacing = 10
        self.padding = 10
        self.size_hint_y = None
        self.bind(minimum_height=self.setter('height'))

        self.add_widget(self.create_log_entry("Bike", "45 min", "137 bpm", "7:00 AM"))
        self.add_widget(self.create_log_entry("Row", "30 min", "145 bpm", "6:45 PM"))
        self.add_widget(self.create_log_entry("Lift", "60 min", "120 bpm", "1:00 PM"))

    def create_log_entry(self, workout, duration, hr, time):
        section = BoxLayout(orientation='vertical', size_hint_y=None, spacing=5)
        section.bind(minimum_height=section.setter('height'))

        toggle_row = BoxLayout(orientation='horizontal', size_hint_y=None, height=40, padding=[10, 0, 10, 0], spacing=10)
        with toggle_row.canvas.before:
            Color(0.4, 0.4, 0.4, 1)
            toggle_row.bg_rect = Rectangle(pos=toggle_row.pos, size=toggle_row.size)
        toggle_row.bind(pos=lambda inst, val: setattr(toggle_row.bg_rect, 'pos', val))
        toggle_row.bind(size=lambda inst, val: setattr(toggle_row.bg_rect, 'size', val))

        title_label = Label(
            text=f"{workout}  {duration}  {hr}  {time}",
            size_hint_x=0.9,
            halign='left',
            valign='middle'
        )
        title_label.bind(size=title_label.setter('text_size'))

        arrow_label = Label(
            text='▶️',
            font_size=40,
            font_name='fonts/NotoEmoji-Regular.ttf',
            size_hint_x=0.1,
            halign='right',
            valign='middle'
        )
        arrow_label.bind(size=arrow_label.setter('text_size'))

        toggle_row.add_widget(title_label)
        toggle_row.add_widget(arrow_label)
        section.add_widget(toggle_row)

        details = BoxLayout(orientation='vertical', padding=[10, 0, 10, 0], spacing=5, size_hint_y=None)
        details.bind(minimum_height=details.setter('height'))
        details.add_widget(Label(text="Pace: 2:05/500m", size_hint_y=None, height=25))
        details.add_widget(Label(text="Calories: 350 kcal", size_hint_y=None, height=25))
        details.add_widget(Label(text="[Graph Placeholder]", size_hint_y=None, height=100))

        content_shown = [False]

        def toggle(*args):
            if content_shown[0]:
                section.remove_widget(details)
                arrow_label.text = "▶️"
            else:
                section.add_widget(details)
                arrow_label.text = "🔽"
            content_shown[0] = not content_shown[0]

        toggle_row.bind(on_touch_down=lambda instance, touch: toggle() if toggle_row.collide_point(*touch.pos) else None)

        return section

class WorkoutLogScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        layout = BoxLayout(orientation='vertical')
        scroll = ScrollView()
        scroll.add_widget(WorkoutLogTab())
        layout.add_widget(scroll)
        self.add_widget(layout)
