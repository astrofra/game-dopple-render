# AGENTS.md

## General guidelines
- All code comments in English
- All variables, functions, symbols names in English
- Prefer lazy evaluation of expressions, cache as little values as possible.
- Long functions are not a problem as long as there code flow is mostly linear.

## Coding/language guidelines
- HTML5/CSS/Tailwind is the software stack we target.
- Python code should not use too much fancy modern features (Python 3.10 max)
- Minimize code dependencies but do not reinvent the wheel if a robust, fiable and well-known solution exists.
- Avoid generic functions that perform runtime dispatch based on a set of rules and prefer very task-specific functions that are called directly (eg. avoid toAbsoluteURL(path, [...]) and instead call the specific resolveProjectURL(path, projectId) when resolving a project URL).
- Do not do defensive code. If some data structure is not as expected the code should fail loudly and as early as possible so it is fixed.
