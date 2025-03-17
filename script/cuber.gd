extends CharacterBody3D

@onready var agent = $NavigationAgent3D
var player : Node = self
var SPEED = 5.0
var wandering = false
var movement_delta: float
var can_move = true
var enemy_type = "cuber"
var fight_instance
var username = "Cuber"
@onready var sub_tex = $SubViewport.get_texture()
@onready var sub = $SubViewport
@onready var sub_cam = $SubViewport/Camera3D
@onready var health_bar = $SubViewport2/ProgressBar
var health = 2
@export var movement_speed: float = 4.0
func _ready() -> void:
	player = null
	health_bar.max_value = health
	wander()
func _process(delta):
	sub_cam.global_position = self.global_position + Vector3(0,0,1.689)
	health_bar.value = health
func _physics_process(delta: float) -> void:
	if not is_on_floor():
			velocity += get_gravity() * delta
	if multiplayer.is_server():
		rpc("pos",global_position)
	if can_move:
		if player != null:
			SPEED = 5
			agent.target_position = player.global_position
				# Do not query when the map has never synchronized and is empty.
			if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
				return
			if agent.is_navigation_finished():
				return

			movement_delta = movement_speed * delta
			var next_path_position: Vector3 = agent.get_next_path_position()
			var new_velocity: Vector3 = global_position.direction_to(next_path_position) * movement_delta
			if agent.avoidance_enabled:
				agent.set_velocity(new_velocity)
			else:
				_on_navigation_agent_3d_velocity_computed(new_velocity)
		else:
			SPEED = 2
			if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
				return
			movement_delta = movement_speed * delta
			var next_path_position: Vector3 = agent.get_next_path_position()
			var new_velocity: Vector3 = global_position.direction_to(next_path_position) * movement_delta
			if agent.avoidance_enabled:
				agent.set_velocity(new_velocity)
			else:
				_on_navigation_agent_3d_velocity_computed(new_velocity)
	move_and_slide()


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	global_position = global_position.move_toward(global_position + safe_velocity, movement_delta)
	move_and_slide()


func _on_i_can_see_you_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_i_can_see_you_body_exited(body: Node3D) -> void:
	if player == body:
		player = null
@rpc("unreliable")
func pos(pos):
	global_position = pos

func turn():
	var random = randi_range(0,0)
	match random:
		0:
			var combatants = fight_instance.get_combatants(self)
			var size = combatants.size()
			var random_key = combatants.keys()[randi() % size]
			var amount = combatants[random_key]
			print(amount)
			await get_tree().create_timer(1.0)
			fight_instance.run_action(self,"Punch",amount)



func wander():
	await get_tree().create_timer(1.0).timeout
	if wandering and player == null:
		return
	else:
		var original = Vector3(global_position.x,global_position.y,global_position.z)
		var target = Vector3(global_position.x + randi_range(-5,5),global_position.y,global_position.z + randi_range(-5,5))
		agent.target_position = target
		await agent.target_reached
		agent.target_position = original
	wander()


func _on_visible() -> void:
	if is_multiplayer_authority():
		print(visible)
		visible = true


func _on_invisible() -> void:
	if is_multiplayer_authority():
		print(visible)
		visible = false
func damage(value):
	health -= value

func _on_start_fight_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.start_fight(self)

func death():
	fight_instance.enemies.remove_at(fight_instance.enemies.find(self))
	fight_instance.kill_me(self)
	self.queue_free()
