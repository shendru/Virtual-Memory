extends Node2D

var request_array: Array[String] = []
const MAX_REQUESTS: int = 4

const RAM_FRAMES: int = 4
var physical_memory: Array[String] = ["","","",""]

var run_simulation: bool = true

var cpu_running: bool = false
var mmu_running: bool = false
var os_running: bool = false

const WAITTIME: int = 3

@onready var VM = $VirtualMemory
@onready var PM = $PhysicalMemory

var free_frames := []

func _ready():
	randomize()
	_sim_start()

func _process(delta: float) -> void:
	if cpu_running:
		$CPU/CPU/CPU.color = Color.ROYAL_BLUE
	else:
		$CPU/CPU/CPU.color = Color.WHITE
	
	if mmu_running:
		$CPU/CPU/MMU.color = Color.ROYAL_BLUE
		$CPU/CPU/TLB.color = Color.ROYAL_BLUE
	else:
		$CPU/CPU/MMU.color = Color.WHITE
		$CPU/CPU/TLB.color = Color.WHITE
	
	if os_running:
		PM.get_node("OS").color = Color.ROYAL_BLUE
		PM.get_node("OS2").color = Color.ROYAL_BLUE
	else:
		PM.get_node("OS").color = Color.WHITE
		PM.get_node("OS2").color = Color.WHITE

func _sim_start():
	await get_tree().create_timer(WAITTIME).timeout
	print("Sim Starts")
	await Generate_Requests()

#===============================================================
func Generate_Requests():
	request_array.clear()
	
	var available_numbers := [0,1,2,3,4,5,6,7]
	available_numbers.shuffle()
	
	for i in range(MAX_REQUESTS):
		var page_num = available_numbers[i]
		request_array.append("Page " + str(page_num))
	
	print("Generated Requests: ", request_array)
	await _create_requests()
#===============================================================
func _create_requests():
	var RQ = $CPU/RequestQueue
	# Clear previous labels if any
	for child in RQ.get_children():
		print("deleted")
		child.queue_free()
	# Create labels for each request
	for request in request_array:
		var new_label = Label.new()
		new_label.name = request      # Set node name
		new_label.text = request      # Set displayed text
		RQ.add_child(new_label)
		
	_run_simulation_now()


func _run_simulation_now():
	while not request_array.is_empty() and run_simulation:
		print("Running Demand Paging Cycle")
		await _run_demand_paging_cycle()
	
	#print("Left the while loop")
	#await get_tree().create_timer(2.0).timeout
	#print("\n✅ Simulation Finished!")
	#print("Final Physical Memory State: ", physical_memory)



func _run_demand_paging_cycle():
	# Step 1: Take first request from queue
	cpu_running = true
	var request = str(request_array.pop_front())
	print("\nCPU → " + request)
	
	
	var label = $CPU/RequestQueue.get_node(request)
	label.set("theme_override_colors/font_color", Color.YELLOW)
	# Convert "Page X" → number X
	var page_id = int(request.split(" ")[1])
	
	await get_tree().create_timer(WAITTIME).timeout
	
	# Step 2: Page Hit or Fault?
	if not _is_page_in_ram(page_id):
		#await get_tree().process_frame
		cpu_running = false
		mmu_running = true
		#await get_tree().create_timer(WAITTIME).timeout
		await _trigger_page_fault(page_id, request)
	else:
		cpu_running = false
		mmu_running = true
		await _highlight_page_hit(str(page_id))
	
#	CLEARS THE REQUESTQUEUE
	$CPU/RequestQueue.get_node(request).queue_free()
	
	print("Request Array has a size of: " + str(request_array.size()))
	if request_array.is_empty() and not free_frames.is_empty():
		print("\n✅ Simulation Finished!")
		print("Final Physical Memory State: ", physical_memory)
		_sim_start()
	elif request_array.is_empty() and free_frames.is_empty():
		physical_memory = ["","","",""]
		_clear_lines()
		_update_physical_memory_display()
		_sim_start()


func _highlight_page_hit(page_id: String):
	# Check if page_id exists in physical_memory
	var _page = "Page " + page_id
	if _page in physical_memory:
		var index = physical_memory.find(_page)
		var hit_page = PM.get_node("Frame " + str(index))
		if hit_page:
			print("HIT PAGE EXISTS")
			var hit_page_original_color = hit_page.color
			hit_page.color = Color.GREEN
			await get_tree().create_timer(WAITTIME).timeout
			hit_page.color = hit_page_original_color
			mmu_running = false
			await get_tree().create_timer(WAITTIME).timeout
		else:
			push_warning("Frame " + str(index) + " does not exist in PM.")
	else:
		print(_page + " not found in physical_memory")



func _trigger_page_fault(page_id: int, request):


	print("PAGE FAULT! Loading Page " + str(page_id))

	free_frames = []

	for i in range(physical_memory.size()):
		if physical_memory[i] == "":
			free_frames.append(i)
	
	$PhysicalMemory.get_node("Body").color = Color.RED
	if free_frames.is_empty():
		print("RAM FULL ❌ → Replacement Needed!")
		PM.get_node("Full").visible = true
		await get_tree().create_timer(WAITTIME).timeout
		PM.get_node("Full").visible = false
		mmu_running = false
		$PhysicalMemory.get_node("Body").color = Color.html("#919091")
		#print("Restarting Simulation")
		#await get_tree().create_timer(1).timeout
		#physical_memory = ["","","",""]
		#_clear_lines()
		#_sim_start()
		return
	await get_tree().create_timer(WAITTIME).timeout
	mmu_running = false
	os_running = true
	$PhysicalMemory.get_node("Body").color = Color.html("#919091")
	
	var random_index = free_frames[randi() % free_frames.size()]
	physical_memory[random_index] = "Page " + str(page_id)

	print("Inserted Page " + str(page_id) + " into Frame " + str(random_index))
	print("Physical Memory State: ", physical_memory)
	
#	LINE
	var _VM = VM.get_node(request)
	var _PM = PM.get_node("Frame " + str(random_index))
	
	await get_tree().create_timer(WAITTIME).timeout
	os_running = false
	
	connect_VM_to_PM(_VM, _PM)
	
	_update_physical_memory_display()
	
	await get_tree().create_timer(WAITTIME).timeout
	
	#if not request_array.has(""):

func connect_VM_to_PM(_VM: ColorRect, _PM: ColorRect):
	var line = Line2D.new()
	line.width = 2
	line.default_color = Color.BLACK
	# Get center positions
	var start = Vector2(_VM.global_position.x + (_VM.size.x / 2), _VM.global_position.y - (_VM.size.y / 2))
	var end = Vector2(_PM.global_position.x - (_PM.size.x / 2), _PM.global_position.y - (_PM.size.y / 2))
	# Add two points for a straight line
	line.add_point(start)
	line.add_point(end)
	# Add line to the scene (under a parent node like Connection)
	$Connection.add_child(line)

func _clear_lines():
	for child in $Connection.get_children():
		print("deleted lines")
		child.queue_free()

func _is_page_in_ram(page_id: int) -> bool:
	return physical_memory.has("Page " + str(page_id))

func _update_physical_memory_display():
	# Loop through the specific frame names
	for i in range(4):
		var frame_name = "Frame %d" % i
		if $PhysicalMemory.has_node(frame_name):
			var frame = $PhysicalMemory.get_node(frame_name)
			var label = frame.get_node("Label")  # Assuming each Frame has a Label child
			
			if i < physical_memory.size():
				label.text = physical_memory[i]  # Could be "" if empty
			else:
				label.text = ""
