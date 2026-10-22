extends Node3D
# Вешается на узел "Beretta Pistol" (он должен быть дочерним узлом Camera3D).
# Дочерний узел "Ammo" — точка, откуда вылетает пуля.

@export var fire_rate: float = 0.15       # пауза между выстрелами, сек[span_7](start_span)[span_7](end_span)
@export var automatic: bool = false        # true — стрельба при удержании ЛКМ[span_8](start_span)[span_8](end_span)

@export_group("Патроны")
@export var magazine_size: int = 13        # размер магазина[span_9](start_span)[span_9](end_span)
@export var max_reserve_ammo: int = 26     # всего патронов в запасе
@export var reload_time: float = 1.5       # время перезарядки, сек[span_10](start_span)[span_10](end_span)
@export var ammo_label_name: String = "Label"  # имя Label[span_11](start_span)[span_11](end_span)

@export_group("Анимация")
@export var animation_player_path: NodePath = "^\"../../AnimationPlayer\"" # путь к AnimationPlayer (или укажите в инспекторе)
@export var trigger_anim_name: String = "berreta trigger animation"      # название вашей анимации

@export_group("Разброс")
@export var spread_min: float = 0.3        # разброс стоя на месте (градусы, половина конуса)[span_12](start_span)[span_12](end_span)
@export var spread_max: float = 5.0        # максимальный разброс[span_13](start_span)[span_13](end_span)
@export var spread_move: float = 2.0       # добавка при движении на полной скорости[span_14](start_span)[span_14](end_span)
@export var spread_air: float = 2.5        # добавка в полёте (прыжок / падение)[span_15](start_span)[span_15](end_span)
@export var spread_per_shot: float = 1.0   # добавка за каждый выстрел[span_16](start_span)[span_16](end_span)
@export var spread_shot_recover: float = 6.0  # скорость восстановления после стрельбы (град/сек)[span_17](start_span)[span_17](end_span)
@export var spread_full_speed: float = 9.0 # скорость, при которой действует полная spread_move[span_18](start_span)[span_18](end_span)
@export var spread_smooth: float = 8.0     # плавность изменения разброса от движения[span_19](start_span)[span_19](end_span)

@export_group("Отдача")
@export var recoil_back: float = 0.06      # откат пистолета назад (м)[span_20](start_span)[span_20](end_span)
@export var recoil_pitch: float = 6.0      # подброс ствола вверх (градусы)[span_21](start_span)[span_21](end_span)
@export var camera_kick: float = 0.8       # подброс камеры (градусы)[span_22](start_span)[span_22](end_span)
@export var recoil_return_speed: float = 14.0[span_23](start_span)[span_23](end_span)

@export_group("Покачивание")
@export var bob_amount: float = 0.012      # амплитуда при ходьбе[span_24](start_span)[span_24](end_span)
@export var bob_speed: float = 1.6         # частота покачивания[span_25](start_span)[span_25](end_span)
@export var sway_amount: float = 0.0008    # смещение от движения мыши[span_26](start_span)[span_26](end_span)
@export var sway_smooth: float = 10.0[span_27](start_span)[span_27](end_span)

@export_group("Прыжок")
@export var air_sway: float = 0.008        # смещение пистолета в полёте[span_28](start_span)[span_28](end_span)
@export var land_dip_amount: float = 0.012 # просадка при приземлении[span_29](start_span)[span_29](end_span)

const BulletScript := preload("res://scripts/bullet.gd")[span_30](start_span)[span_30](end_span)

@onready var muzzle: Node3D = $Ammo[span_31](start_span)[span_31](end_span)

var cooldown: float = 0.0[span_32](start_span)[span_32](end_span)
var camera: Camera3D[span_33](start_span)[span_33](end_span)
var player: CharacterBody3D[span_34](start_span)[span_34](end_span)

var base_basis: Basis[span_35](start_span)[span_35](end_span)
var base_pos: Vector3[span_36](start_span)[span_36](end_span)
var cam_base_rot_x: float = 0.0[span_37](start_span)[span_37](end_span)

# Патроны
var ammo: int = 0                          # патроны в магазине
var reserve_ammo: int = 0                  # патроны в запасе
var reloading: bool = false[span_38](start_span)[span_38](end_span)
var reload_left: float = 0.0[span_39](start_span)[span_39](end_span)
var ammo_label: Label[span_40](start_span)[span_40](end_span)

# Анимация
var anim_player: AnimationPlayer

# Состояние эффектов
var recoil_offset: float = 0.0   # 0..1 текущая сила отдачи[span_41](start_span)[span_41](end_span)
var cam_kick_current: float = 0.0[span_42](start_span)[span_42](end_span)
var bob_time: float = 0.0[span_43](start_span)[span_43](end_span)
var bob_offset := Vector3.ZERO[span_44](start_span)[span_44](end_span)
var sway_target := Vector2.ZERO[span_45](start_span)[span_45](end_span)
var sway_current := Vector2.ZERO[span_46](start_span)[span_46](end_span)
var air_offset := 0.0[span_47](start_span)[span_47](end_span)
var air_pitch := 0.0[span_48](start_span)[span_48](end_span)
var land_dip := 0.0[span_49](start_span)[span_49](end_span)
var was_on_floor := true[span_50](start_span)[span_50](end_span)
var last_air_vy := 0.0[span_51](start_span)[span_51](end_span)

# Разброс
var current_spread: float = 0.0  # итоговый разброс сейчас (градусы)[span_52](start_span)[span_52](end_span)
var state_spread: float = 0.0    # часть от движения / полёта[span_53](start_span)[span_53](end_span)
var shot_spread: float = 0.0     # часть от стрельбы[span_54](start_span)[span_54](end_span)

var flash_mesh: MeshInstance3D[span_55](start_span)[span_55](end_span)
var flash_light: OmniLight3D[span_56](start_span)[span_56](end_span)


func _ready() -> void:
	base_basis = transform.basis[span_57](start_span)[span_57](end_span)
	base_pos = position[span_58](start_span)[span_58](end_span)

	camera = get_parent() as Camera3D[span_59](start_span)[span_59](end_span)
	if camera:
		cam_base_rot_x = camera.rotation.x[span_60](start_span)[span_60](end_span)

	# Ищем персонажа вверх по дереву
	var n: Node = get_parent()[span_61](start_span)[span_61](end_span)
	while n and not (n is CharacterBody3D):
		n = n.get_parent()[span_62](start_span)[span_62](end_span)
	player = n as CharacterBody3D[span_63](start_span)[span_63](end_span)

	# Поиск AnimationPlayer
	if has_node(animation_player_path):
		anim_player = get_node(animation_player_path) as AnimationPlayer
	else:
		anim_player = get_tree().root.find_child("AnimationPlayer", true, false) as AnimationPlayer

	# Инициализация патронов (13 в магазине, 13 в запасе = всего 26)
	ammo = magazine_size
	reserve_ammo = max_reserve_ammo - magazine_size

	ammo_label = get_tree().root.find_child(ammo_label_name, true, false) as Label[span_64](start_span)[span_64](end_span)
	_update_hud()

	current_spread = spread_min[span_65](start_span)[span_65](end_span)

	_create_muzzle_flash()[span_66](start_span)[span_66](end_span)


func _create_muzzle_flash() -> void:
	flash_mesh = MeshInstance3D.new()[span_67](start_span)[span_67](end_span)
	var sphere := SphereMesh.new()[span_68](start_span)[span_68](end_span)
	sphere.radius = 0.05[span_69](start_span)[span_69](end_span)
	sphere.height = 0.1[span_70](start_span)[span_70](end_span)
	flash_mesh.mesh = sphere[span_71](start_span)[span_71](end_span)
	var mat := StandardMaterial3D.new()[span_72](start_span)[span_72](end_span)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED[span_73](start_span)[span_73](end_span)
	mat.albedo_color = Color(1.0, 0.8, 0.3)[span_74](start_span)[span_74](end_span)
	mat.emission_enabled = true[span_75](start_span)[span_75](end_span)
	mat.emission = Color(1.0, 0.7, 0.2)[span_76](start_span)[span_76](end_span)
	mat.emission_energy_multiplier = 4.0[span_77](start_span)[span_77](end_span)
	flash_mesh.material_override = mat[span_78](start_span)[span_78](end_span)
	flash_mesh.visible = false[span_79](start_span)[span_79](end_span)
	muzzle.add_child(flash_mesh)[span_80](start_span)[span_80](end_span)

	flash_light = OmniLight3D.new()[span_81](start_span)[span_81](end_span)
	flash_light.light_color = Color(1.0, 0.75, 0.35)[span_82](start_span)[span_82](end_span)
	flash_light.light_energy = 3.0[span_83](start_span)[span_83](end_span)
	flash_light.omni_range = 6.0[span_84](start_span)[span_84](end_span)
	flash_light.visible = false[span_85](start_span)[span_85](end_span)
	muzzle.add_child(flash_light)[span_86](start_span)[span_86](end_span)


func _update_hud() -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [ammo, reserve_ammo]


func _process(delta: float) -> void:
	cooldown = max(cooldown - delta, 0.0)[span_87](start_span)[span_87](end_span)

	# Перезарядка
	if reloading:
		reload_left -= delta[span_88](start_span)[span_88](end_span)
		if reload_left <= 0.0:
			reloading = false[span_89](start_span)[span_89](end_span)
			
			# Расчёт пополнения из запаса
			var needed := magazine_size - ammo
			var to_reload := mini(needed, reserve_ammo)
			ammo += to_reload
			reserve_ammo -= to_reload
			
			_update_hud()[span_90](start_span)[span_90](end_span)

	if automatic and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):[span_91](start_span)[span_91](end_span)
		shoot()[span_92](start_span)[span_92](end_span)

	_update_spread(delta)[span_93](start_span)[span_93](end_span)
	_update_visual_motion(delta)[span_94](start_span)[span_94](end_span)


func _unhandled_input(event: InputEvent) -> void:
	# Инерция пистолета от движения мыши
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:[span_95](start_span)[span_95](end_span)
		sway_target = Vector2(-event.relative.x, event.relative.y) * sway_amount[span_96](start_span)[span_96](end_span)
		sway_target = sway_target.limit_length(0.04)[span_97](start_span)[span_97](end_span)

	# Перезарядка на R
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:[span_98](start_span)[span_98](end_span)
		reload()[span_99](start_span)[span_99](end_span)

	if automatic:[span_100](start_span)[span_100](end_span)
		return[span_101](start_span)[span_101](end_span)
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:[span_102](start_span)[span_102](end_span)
		shoot()[span_103](start_span)[span_103](end_span)


func _update_spread(delta: float) -> void:
	var target := 0.0[span_104](start_span)[span_104](end_span)
	if player:[span_105](start_span)[span_105](end_span)
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()[span_106](start_span)[span_106](end_span)
		target += spread_move * clampf(horizontal_speed / spread_full_speed, 0.0, 1.0)[span_107](start_span)[span_107](end_span)
		if not player.is_on_floor():[span_108](start_span)[span_108](end_span)
			target += spread_air[span_109](start_span)[span_109](end_span)
	state_spread = lerpf(state_spread, target, clampf(delta * spread_smooth, 0.0, 1.0))[span_110](start_span)[span_110](end_span)

	shot_spread = move_toward(shot_spread, 0.0, spread_shot_recover * delta)[span_111](start_span)[span_111](end_span)

	current_spread = clampf(spread_min + state_spread + shot_spread, spread_min, spread_max)[span_112](start_span)[span_112](end_span)


func _update_visual_motion(delta: float) -> void:
	# Покачивание при ходьбе
	var target_bob := Vector3.ZERO[span_113](start_span)[span_113](end_span)
	if player and player.is_on_floor():[span_114](start_span)[span_114](end_span)
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()[span_115](start_span)[span_115](end_span)
		if horizontal_speed > 0.1:[span_116](start_span)[span_116](end_span)
			bob_time += delta * horizontal_speed * bob_speed[span_117](start_span)[span_117](end_span)
			var strength := clampf(horizontal_speed / 5.0, 0.0, 2.0)[span_118](start_span)[span_118](end_span)
			target_bob.x = sin(bob_time) * bob_amount * strength[span_119](start_span)[span_119](end_span)
			target_bob.y = absf(cos(bob_time)) * bob_amount * strength[span_120](start_span)[span_120](end_span)
		else:
			bob_time += delta * 2.0[span_121](start_span)[span_121](end_span)
			target_bob.y = sin(bob_time) * 0.0025[span_122](start_span)[span_122](end_span)
	bob_offset = bob_offset.lerp(target_bob, clampf(delta * 10.0, 0.0, 1.0))[span_123](start_span)[span_123](end_span)

	# Прыжок / приземление
	var target_air := 0.0[span_124](start_span)[span_124](end_span)
	var target_air_pitch := 0.0[span_125](start_span)[span_125](end_span)
	if player:[span_126](start_span)[span_126](end_span)
		var on_floor := player.is_on_floor()[span_127](start_span)[span_127](end_span)
		if not on_floor:[span_128](start_span)[span_128](end_span)
			var vy := player.velocity.y[span_129](start_span)[span_129](end_span)
			last_air_vy = vy[span_130](start_span)[span_130](end_span)
			target_air = clampf(-vy * air_sway, -0.06, 0.06)[span_131](start_span)[span_131](end_span)
			target_air_pitch = clampf(-vy * 0.02, -0.15, 0.15)[span_132](start_span)[span_132](end_span)
		elif not was_on_floor:[span_133](start_span)[span_133](end_span)
			land_dip = clampf(absf(last_air_vy) * land_dip_amount, 0.0, 0.12)[span_134](start_span)[span_134](end_span)
		was_on_floor = on_floor[span_135](start_span)[span_135](end_span)
	air_offset = lerpf(air_offset, target_air, clampf(delta * 8.0, 0.0, 1.0))[span_136](start_span)[span_136](end_span)
	air_pitch = lerpf(air_pitch, target_air_pitch, clampf(delta * 8.0, 0.0, 1.0))[span_137](start_span)[span_137](end_span)
	land_dip = lerpf(land_dip, 0.0, clampf(delta * 9.0, 0.0, 1.0))[span_138](start_span)[span_138](end_span)

	# Инерция от мыши
	sway_target = sway_target.lerp(Vector2.ZERO, clampf(delta * sway_smooth, 0.0, 1.0))[span_139](start_span)[span_139](end_span)
	sway_current = sway_current.lerp(sway_target, clampf(delta * sway_smooth, 0.0, 1.0))[span_140](start_span)[span_140](end_span)

	# Возврат отдачи
	recoil_offset = lerpf(recoil_offset, 0.0, clampf(delta * recoil_return_speed, 0.0, 1.0))[span_141](start_span)[span_141](end_span)
	cam_kick_current = lerpf(cam_kick_current, 0.0, clampf(delta * recoil_return_speed * 0.6, 0.0, 1.0))[span_142](start_span)[span_142](end_span)

	# Опускание при перезарядке
	var reload_dip := 0.0[span_143](start_span)[span_143](end_span)
	if reloading and reload_time > 0.0:[span_144](start_span)[span_144](end_span)
		var progress := 1.0 - reload_left / reload_time[span_145](start_span)[span_145](end_span)
		reload_dip = sin(clampf(progress, 0.0, 1.0) * PI)[span_146](start_span)[span_146](end_span)

	# Применение изменений к трансформу
	var offset := bob_offset + Vector3(sway_current.x, sway_current.y, 0.0)[span_147](start_span)[span_147](end_span)
	offset.y += air_offset - land_dip - reload_dip * 0.08[span_148](start_span)[span_148](end_span)
	offset.z += recoil_offset * recoil_back[span_149](start_span)[span_149](end_span)
	var pitch_rot := Basis(Vector3.RIGHT, deg_to_rad(recoil_pitch) * recoil_offset + air_pitch - land_dip * 1.5 - reload_dip * 0.5)[span_150](start_span)[span_150](end_span)
	var sway_rot := Basis(Vector3.UP, sway_current.x * 3.0)[span_151](start_span)[span_151](end_span)
	transform = Transform3D(pitch_rot * sway_rot * base_basis, base_pos + offset)[span_152](start_span)[span_152](end_span)

	# Подброс камеры
	if camera:[span_153](start_span)[span_153](end_span)
		camera.rotation.x = cam_base_rot_x + deg_to_rad(camera_kick) * cam_kick_current[span_154](start_span)[span_154](end_span)


func _apply_spread(b: Basis) -> Basis:
	var ang := randf() * TAU[span_155](start_span)[span_155](end_span)
	var r := sqrt(randf()) * deg_to_rad(current_spread)[span_156](start_span)[span_156](end_span)
	var out := b.rotated(b.y.normalized(), cos(ang) * r)[span_157](start_span)[span_157](end_span)
	out = out.rotated(out.x.normalized(), sin(ang) * r)[span_158](start_span)[span_158](end_span)
	return out.orthonormalized()[span_159](start_span)[span_159](end_span)


func reload() -> void:
	# Нельзя перезарядиться, если запас патронов пуст или магазин уже полный
	if reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return
	reloading = true[span_160](start_span)[span_160](end_span)
	reload_left = reload_time[span_161](start_span)[span_161](end_span)


func shoot() -> void:
	if cooldown > 0.0 or reloading:
		return
	if ammo <= 0:
		reload()[span_162](start_span)[span_162](end_span)
		return

	cooldown = fire_rate

	# Запуск вашей анимации
	if anim_player and anim_player.has_animation(trigger_anim_name):
		anim_player.stop()
		anim_player.play(trigger_anim_name)

	_fire()


# Выстрел
func _fire() -> void:
	ammo -= 1
	_update_hud()[span_163](start_span)[span_163](end_span)

	var bullet := Node3D.new()[span_164](start_span)[span_164](end_span)
	bullet.set_script(BulletScript)[span_165](start_span)[span_165](end_span)
	get_tree().current_scene.add_child(bullet)[span_166](start_span)[span_166](end_span)
	var cam := get_viewport().get_camera_3d()[span_167](start_span)[span_167](end_span)
	var dir_basis := cam.global_transform.basis if cam else muzzle.global_transform.basis[span_168](start_span)[span_168](end_span)
	dir_basis = _apply_spread(dir_basis)[span_169](start_span)[span_169](end_span)
	bullet.global_transform = Transform3D(dir_basis, muzzle.global_position)[span_170](start_span)[span_170](end_span)

	shot_spread = minf(shot_spread + spread_per_shot, spread_max)[span_171](start_span)[span_171](end_span)

	recoil_offset = 1.0[span_172](start_span)[span_172](end_span)
	cam_kick_current = 1.0[span_173](start_span)[span_173](end_span)

	_show_muzzle_flash()[span_174](start_span)[span_174](end_span)


func _show_muzzle_flash() -> void:
	flash_mesh.visible = true[span_175](start_span)[span_175](end_span)
	flash_light.visible = true[span_176](start_span)[span_176](end_span)
	flash_mesh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)[span_177](start_span)[span_177](end_span)
	flash_mesh.scale = Vector3.ONE * randf_range(0.7, 1.3)[span_178](start_span)[span_178](end_span)
	await get_tree().create_timer(0.05).timeout[span_179](start_span)[span_179](end_span)
	if is_instance_valid(flash_mesh):[span_180](start_span)[span_180](end_span)
		flash_mesh.visible = false[span_181](start_span)[span_181](end_span)
		flash_light.visible = false[span_182](start_span)[span_182](end_span)
