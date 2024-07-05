extends Node3D

@onready var CurrentFPS = $CurrentFPS

func _ready():
	Engine.max_fps = 60

func _process(_delta):
	CurrentFPS.text = str(Engine.get_frames_per_second()) + "/" + str(Engine.max_fps)
