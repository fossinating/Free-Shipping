extends StaticBody


func _on_Visible_Area_body_exited(body):
	if body in $"Export Area".get_overlapping_bodies():
		if body is Box:
			Globals.root.export_box(body)
		else:
			body.queue_free()
