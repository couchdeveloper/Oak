final class Context {
    let terminateProxy: (Swift.Error) -> Void
    var tasks: [ID: (Int, Task<Void, Never>)] = [:]

    init(terminateProxy: @escaping (Swift.Error) -> Void) {
        self.terminateProxy = terminateProxy
    }

    deinit {
        for (_, task) in tasks.values {
            task.cancel()
        }
    }

    func register(
        task: Task<Void, Never>,
        uid: Int,
        id: ID
    ) {
        if let (_, prevTask) = tasks[id] {
            prevTask.cancel()
        }
        tasks[id] = (uid, task)
    }

    func removeCompleted(
        uid: Int,
        id: ID,
        isolated: isolated any Actor
    ) {
        if let (storedUid, _) = tasks[id], storedUid == uid {
            tasks[id] = nil
        }
    }

    func uid() -> Int {
        defer { _uid += 1 }
        return _uid
    }

    func id() -> ID {
        defer { _id += 1 }
        return ID(_id)
    }

    func cancelTask(
        id: ID,
        isolated: isolated any Actor
    ) {
        if let (_, task) = tasks[id] {
            task.cancel()
            tasks[id] = nil
        }
    }

    func cancellAllTasks() {
        for (_, task) in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    func terminate(_ error: Swift.Error) {
        terminateProxy(error)
    }

    private var _uid = 0
    private var _id = 0
}
