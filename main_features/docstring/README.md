# Docstring Tool

## Overview

The Docstring Tool helps you generate comprehensive docstrings for your code functions, classes, and methods. It uses AI to analyze your code and create descriptive, well-formatted documentation that follows industry standards and best practices.

## What it does

This tool performs the following operations:

1. **Analyzes code structure** - Examines your code to understand function signatures and logic
2. **Generates docstrings** - Uses AI to create descriptive documentation for your code
3. **Supports multiple languages** - Works with Python, JavaScript, TypeScript, and other languages
4. **Follows standards** - Generates docstrings that follow language-specific conventions
5. **Provides templates** - Offers different docstring formats and styles
6. **Interactive editing** - Allows you to review and edit generated docstrings

## Features

- **Multi-language support** - Works with Python, JavaScript, TypeScript, Java, C#, and more
- **AI-powered generation** - Uses AI to understand code context and generate relevant documentation
- **Standard compliance** - Follows language-specific docstring conventions (Google, NumPy, JSDoc, etc.)
- **Interactive workflow** - Review and edit generated docstrings before applying
- **Batch processing** - Generate docstrings for multiple functions at once
- **Template selection** - Choose from different docstring styles and formats
- **Code analysis** - Automatically detects function parameters, return types, and logic

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option from the menu (if available)

# Direct execution
./main_features/docstring/generate_docstring.sh
```

### Direct execution

```bash
# Bash
./main_features/docstring/generate_docstring.sh

# PowerShell
./main_features/docstring/generate_docstring.ps1
```

## Workflow

### Step 1: Code Selection
The tool helps you select the code you want to document:

```
📝 Docstring Generator
=====================

🔍 Select the code you want to document:

1) Current file
2) Specific function/method
3) Multiple functions
4) Entire class
5) Custom selection

Enter your choice [1]: 2
```

### Step 2: Language Detection
The tool detects the programming language and suggests appropriate docstring format:

```
🌐 Detected language: Python
📋 Available docstring formats:

1) Google style (recommended)
2) NumPy style
3) Sphinx style
4) Plain text
5) Custom format

Enter your choice [1]: 1
```

### Step 3: AI Analysis
The tool analyzes your code using AI:

```
🤖 Analyzing code structure...

📋 Function analysis:
   Name: calculate_user_score
   Parameters: user_id (int), activity_data (dict)
   Return type: float
   Logic: Calculates user engagement score based on activity data
```

### Step 4: Docstring Generation
The tool generates a comprehensive docstring:

```
📝 Generated docstring:

def calculate_user_score(user_id: int, activity_data: dict) -> float:
    """Calculate user engagement score based on activity data.

    This function analyzes user activity data to compute an engagement
    score that reflects the user's level of interaction with the platform.

    Args:
        user_id (int): The unique identifier of the user.
        activity_data (dict): Dictionary containing user activity metrics.
            Expected keys:
            - 'login_count': Number of times user logged in
            - 'posts_created': Number of posts created by user
            - 'comments_made': Number of comments made by user
            - 'time_spent': Total time spent on platform (minutes)

    Returns:
        float: User engagement score between 0.0 and 100.0.

    Raises:
        ValueError: If user_id is negative or activity_data is empty.
        KeyError: If required activity_data keys are missing.

    Example:
        >>> activity = {
        ...     'login_count': 15,
        ...     'posts_created': 5,
        ...     'comments_made': 12,
        ...     'time_spent': 240
        ... }
        >>> score = calculate_user_score(123, activity)
        >>> print(f"User score: {score}")
        User score: 78.5
    """
```

### Step 5: Review and Apply
Review the generated docstring and apply it to your code:

```
👉 Apply this docstring to your code? [Y/n/e]: y

✅ Docstring applied successfully!

💡 Next steps:
   1. Review the generated docstring
   2. Test your function to ensure it works correctly
   3. Update docstring if needed based on testing
   4. Commit your documented code
```

## Example Output

```
📝 Docstring Generator
=====================

🔍 Analyzing code structure...

📋 Function: calculate_user_score
📍 File: src/utils/user_metrics.py
🌐 Language: Python

🤖 Generating docstring using AI...

📝 Generated docstring:

def calculate_user_score(user_id: int, activity_data: dict) -> float:
    """Calculate user engagement score based on activity data.

    This function analyzes user activity data to compute an engagement
    score that reflects the user's level of interaction with the platform.
    The score is calculated using a weighted formula that considers login
    frequency, content creation, community participation, and time spent.

    Args:
        user_id (int): The unique identifier of the user. Must be positive.
        activity_data (dict): Dictionary containing user activity metrics.
            Required keys:
            - login_count (int): Number of times user logged in
            - posts_created (int): Number of posts created by user
            - comments_made (int): Number of comments made by user
            - time_spent (int): Total time spent on platform (minutes)

    Returns:
        float: User engagement score between 0.0 and 100.0, where higher
            scores indicate more engaged users.

    Raises:
        ValueError: If user_id is negative or activity_data is empty.
        KeyError: If required activity_data keys are missing.
        TypeError: If activity_data values are not of expected types.

    Example:
        >>> activity = {
        ...     'login_count': 15,
        ...     'posts_created': 5,
        ...     'comments_made': 12,
        ...     'time_spent': 240
        ... }
        >>> score = calculate_user_score(123, activity)
        >>> print(f"User score: {score}")
        User score: 78.5

    Note:
        The scoring algorithm weights recent activity more heavily than
        older activity. Scores are normalized to ensure fair comparison
        across different user activity patterns.
    """

👉 Apply this docstring to your code? [Y/n/e]: y

✅ Docstring applied successfully!

🎉 Documentation completed!
```

## Supported Languages

### Python
- **Google style** - Clean, readable format with clear sections
- **NumPy style** - Scientific computing format with detailed parameter descriptions
- **Sphinx style** - ReStructuredText format for Sphinx documentation
- **Plain text** - Simple, minimal documentation

### JavaScript/TypeScript
- **JSDoc style** - Standard JavaScript documentation format
- **TypeScript** - Enhanced JSDoc with type annotations
- **ES6+** - Modern JavaScript features and syntax

### Other Languages
- **Java** - Javadoc format
- **C#** - XML documentation format
- **PHP** - PHPDoc format
- **Ruby** - RDoc format

## Benefits

- **Time saving** - Automates the tedious process of writing docstrings
- **Consistency** - Ensures all functions follow the same documentation style
- **Completeness** - AI generates comprehensive documentation covering all aspects
- **Best practices** - Follows language-specific documentation conventions
- **Code quality** - Better documentation leads to more maintainable code
- **Team collaboration** - Clear documentation helps team members understand code

## Tips

- **Review generated content** - Always review and customize AI-generated docstrings
- **Test your functions** - Ensure docstrings accurately describe function behavior
- **Keep documentation updated** - Update docstrings when function signatures change
- **Use examples** - Include practical examples in your docstrings
- **Be specific** - Describe parameters, return values, and exceptions clearly
- **Follow conventions** - Use the standard docstring format for your language

## Error Handling

The tool handles various error conditions:

- **No code detected** - Guides you to select valid code for documentation
- **AI generation failures** - Falls back to template-based docstring generation
- **Invalid language** - Detects unsupported languages and provides alternatives
- **File access issues** - Reports if code files cannot be read or modified
- **Syntax errors** - Handles code with syntax errors gracefully

## Integration

This tool integrates seamlessly with other dev tools:

- **Commit tools** - Document functions before committing code changes
- **Git log explorer** - Review function history to include in docstrings
- **Code review** - Generate documentation as part of code review process
- **Project setup** - Document functions during initial project setup
- **README creation** - Include documented functions in project documentation 