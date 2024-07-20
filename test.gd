@tool
extends Node2D

@export
var num := 10:
	set(value):
		num = value
		for i in num:
			print(i)
			num -= 1

