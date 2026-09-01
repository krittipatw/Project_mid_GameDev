extends Node

@onready var scorelabel: Label = $"../CanvasLayer/scorelabel"

var score = 0

func _updatescore(value):
	score += value
	#updating the text with new score 
	#str function is used to convert a varibale to string type
	scorelabel.text = "SCORE : " + str(score)
