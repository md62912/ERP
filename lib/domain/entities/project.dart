enum ProjectStatus { planning, active, onHold, completed, cancelled }
enum TaskStatus { todo, inProgress, inReview, blocked, done }
enum TaskPriority { low, medium, high, urgent }

String enumToDb(Enum value) {
  final name = value.name;
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    final char = String.fromCharCode(rune);
    if (char == char.toUpperCase() && char != char.toLowerCase()) {
      buffer.write('_${char.toLowerCase()}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

T _enumFromDb<T extends Enum>(List<T> values, String? dbValue, T fallback) {
  if (dbValue == null) return fallback;
  return values.firstWhere((e) => enumToDb(e) == dbValue, orElse: () => fallback);
}

class Project {
  final String id;
  final String name;
  final String? description;
  final String? clientId;
  final String? ownerId;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? budget;

  const Project({
    required this.id,
    required this.name,
    this.description,
    this.clientId,
    this.ownerId,
    this.status = ProjectStatus.planning,
    this.startDate,
    this.endDate,
    this.budget,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        clientId: json['client_id'] as String?,
        ownerId: json['owner_id'] as String?,
        status: _enumFromDb(ProjectStatus.values, json['status'] as String?, ProjectStatus.planning),
        startDate: json['start_date'] == null ? null : DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] == null ? null : DateTime.parse(json['end_date'] as String),
        budget: (json['budget'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'client_id': clientId,
        'owner_id': ownerId,
        'status': enumToDb(status),
        'start_date': startDate?.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'budget': budget,
      };
}

class ProjectTask {
  final String id;
  final String projectId;
  final String? milestoneId;
  final String title;
  final String? description;
  final String? assigneeId;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final double? estimatedHours;

  const ProjectTask({
    required this.id,
    required this.projectId,
    this.milestoneId,
    required this.title,
    this.description,
    this.assigneeId,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.estimatedHours,
  });

  factory ProjectTask.fromJson(Map<String, dynamic> json) => ProjectTask(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        milestoneId: json['milestone_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        assigneeId: json['assignee_id'] as String?,
        status: _enumFromDb(TaskStatus.values, json['status'] as String?, TaskStatus.todo),
        priority: _enumFromDb(TaskPriority.values, json['priority'] as String?, TaskPriority.medium),
        dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
        estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'project_id': projectId,
        'milestone_id': milestoneId,
        'title': title,
        'description': description,
        'assignee_id': assigneeId,
        'status': enumToDb(status),
        'priority': enumToDb(priority),
        'due_date': dueDate?.toIso8601String().split('T').first,
        'estimated_hours': estimatedHours,
      };
}

class ScheduleEvent {
  final String id;
  final String? projectId;
  final String title;
  final String? description;
  final String eventType;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? createdBy;

  const ScheduleEvent({
    required this.id,
    this.projectId,
    required this.title,
    this.description,
    this.eventType = 'meeting',
    this.location,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.createdBy,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
        id: json['id'] as String,
        projectId: json['project_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventType: json['event_type'] as String? ?? 'meeting',
        location: json['location'] as String?,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        isAllDay: json['is_all_day'] as bool? ?? false,
        createdBy: json['created_by'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'project_id': projectId,
        'title': title,
        'description': description,
        'event_type': eventType,
        'location': location,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_all_day': isAllDay,
      };
}
