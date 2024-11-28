--!native
--!optimize 2
--!strict

local Yumina = require("@yumina")

local DEFAULT_TIME_SLICE = 0.016

type Array<T> = { [number]: T }
type Map<K, V> = { [K]: V }

type Task = {
	next: Task?,
	prev: Task?,
	taskId: number
}

type Scheduler = {
	heap: Array<number>,
	size: number,
	taskToIndex: Map<number, number>,
	taskList: {
		head: Task?,
		tail: Task?
	},
	taskIdToTask: Map<number, Task>,
	executable: Map<number, boolean>
}

local Scheduler = {}
Scheduler.__index = Scheduler

local Component = {
	Callback = 1,
	State = 2,
	Depends = 3
}

function Scheduler.new(): Scheduler
	local self = setmetatable({}, Scheduler)
	self.heap = table.create(8)
	self.size = 0
	self.taskToIndex = {}
	self.taskList = {}
	self.taskList.head = nil
	self.taskList.tail = nil
	self.taskIdToTask = {}
	self.executable = {}
	return self :: any
end

local function CreateTask(taskId: number): Task
	return {
		next = nil,
		prev = nil,
		taskId = taskId
	}
end

function Scheduler.Task(self: Scheduler, config: {
	callback: (deltaTime: number) -> (),
	state: any?
	}): Task
	local taskId = Yumina:Entity()

	Yumina
		:Set(taskId, Component.Callback, config.callback)
		:Set(taskId, Component.State, config.state or "Ready")
		:Set(taskId, Component.Depends, table.create(4))

	local task = CreateTask(taskId)

	if not self.taskList.head then
		self.taskList.head = task
		self.taskList.tail = task
	else
		task.prev = self.taskList.tail
		if self.taskList.tail then
			self.taskList.tail.next = task
		end
		self.taskList.tail = task
	end

	self.taskIdToTask[taskId] = task
	self.size += 1
	self.heap[self.size] = taskId
	self.taskToIndex[taskId] = self.size

	return task
end

function Scheduler.DependsOn(self: Scheduler, dependent: Task, dependency: Task): Scheduler
	local depends = Yumina:Has(dependent.taskId, Component.Depends)
	if depends then
		depends[#depends + 1] = dependency.taskId
	end
	return self
end

local function CreateSortTables(size: number): (Map<number, Array<number>>, Map<number, number>, Array<number>, Array<number>)
	return {}, {}, table.create(size), table.create(size)
end

function Scheduler.Sort(self: Scheduler): ()
	local adjacency, inDegree, queue, sorted = CreateSortTables(self.size)
	local queueSize = 0

	for i = 1, self.size do
		local taskId = self.heap[i]
		adjacency[taskId] = table.create(4)
		inDegree[taskId] = 0
	end

	for i = 1, self.size do
		local taskId = self.heap[i]
		local depends = Yumina:Has(taskId, Component.Depends)
		if depends then
			for _, dependencyId in depends do
				table.insert(adjacency[dependencyId], taskId)
				inDegree[taskId] += 1
			end
		end
	end

	for taskId in adjacency do
		if inDegree[taskId] == 0 then
			queueSize += 1
			queue[queueSize] = taskId
		end
	end

	local sortedSize = 0
	while queueSize > 0 do
		local taskId = queue[queueSize]
		queue[queueSize] = nil
		queueSize -= 1

		sortedSize += 1
		sorted[sortedSize] = taskId

		for _, neighbor in adjacency[taskId] do
			inDegree[neighbor] -= 1
			if inDegree[neighbor] == 0 then
				queueSize += 1
				queue[queueSize] = neighbor
			end
		end
	end

	if sortedSize ~= self.size then
		error("Cyclic dependency detected")
	end

	table.move(sorted, 1, sortedSize, 1, self.heap)
	table.clear(self.taskToIndex)

	for i = 1, self.size do
		self.taskToIndex[self.heap[i]] = i
	end
end

function Scheduler.Update(self: Scheduler, deltaTime: number): ()
	deltaTime = deltaTime or DEFAULT_TIME_SLICE
	table.clear(self.executable)

	local heap = self.heap
	for i = 1, self.size do
		local taskId = heap[i]
		local callback = Yumina:Has(taskId, Component.Callback)
		if callback then
			callback(deltaTime)
		end
		self.executable[taskId] = true
	end
end

return Scheduler.new()