"""
Shared Constants for Model Definitions
=========================================
Centralizes repeated string literals to follow DRY principle.
Resolves SonarQube findings: python:S1192
"""

# ForeignKey references (used across multiple models)
USERS_ID = "users.id"
LBB_EVENTS_ID = "lbb_events.id"
ACADEMIC_YEARS_ID = "academic_years.id"
SCHOOLS_ID = "schools.id"
LIFE_SKILLS_CLASSES_ID = "life_skills_classes.id"

# Cascade rules
CASCADE_ALL_DELETE_ORPHAN = "all, delete-orphan"
