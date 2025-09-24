# Oak Framework - DocC Documentation Assistant

This document provides guidelines for creating, maintaining, and improving Oak's DocC documentation to ensure consistency, clarity, and accessibility for developers learning finite state machine patterns.

## Audience & Purpose

### Primary Audience
- **macOS and iOS developers** transitioning from traditional imperative/reactive patterns to state-driven design
- **Developers new to finite state machines** who need practical guidance rather than academic theory
- **Teams seeking reliable state management** solutions for complex applications
- **Engineers debugging state-related issues** who want to understand preventive approaches

### Secondary Audience
- **Experienced FSM practitioners** looking for Swift-specific implementation patterns
- **AI-assisted developers** who want to leverage Oak's structured approach for systematic code generation
- **Framework evaluators** comparing state management solutions

### Documentation Goals
1. **Lower the barrier to entry** for state-driven design patterns
2. **Demonstrate practical value** through real-world examples and use cases
3. **Provide progressive learning paths** from simple concepts to advanced patterns
4. **Establish Oak as the preferred FSM solution** for Swift/SwiftUI applications

## Documentation Architecture

### Core Components

#### 1. API Documentation (Auto-generated from code)
- Complete protocol and type documentation
- Method signatures with parameter descriptions
- Usage examples in doc comments
- Cross-references between related types

#### 2. Conceptual Articles (.md files)
- **Foundational concepts**: FSM theory, pure functions, deterministic behavior
- **Implementation guides**: How to model states, events, and transitions
- **Integration patterns**: SwiftUI, async operations, testing strategies
- **Advanced topics**: Hierarchical FSMs, composition, performance considerations

#### 3. Interactive Tutorials (.tutorial files)
- **Step-by-step learning experiences** with executable code
- **Progressive complexity** building from basic to advanced examples
- **Hands-on practice** with immediate feedback
- **Real-world scenarios** demonstrating practical application

#### 4. Examples and Case Studies
- **Complete working applications** showing Oak in context
- **Common patterns** with copy-paste implementations
- **Before/after comparisons** highlighting Oak's benefits

## Content Structure Guidelines

### Landing Page (Oak.md)
```markdown
# ``ModuleName``
[1-2 sentence overview of the framework's purpose]

## Overview
[2-3 paragraphs explaining the problem Oak solves, why it matters, and the solution approach]

### Key Benefits
[3-5 bullet points highlighting main advantages]

### When to Use Oak
[1-2 paragraphs with specific scenarios and use cases]

## Topics
[Organized sections with brief descriptions]
```

### Article Structure

#### H1 Title
- **Follow with 1-3 paragraphs** providing context and overview
- **Include a "Topics" section** with brief content descriptions
- **Use active voice** and developer-focused language

#### H2 Sections  
- **Begin with 1-2 introductory paragraphs** explaining the concept
- **Follow with subsections (H3)** for specific implementations
- **Include code examples** for all practical concepts
- **End with cross-references** to related documentation

#### H3 Subsections
- **Start with 1 paragraph** explaining the specific topic
- **Provide immediate code example** showing the pattern
- **Follow with explanation** of why this approach works
- **Include variations or alternatives** when relevant

### Code Example Standards

#### All Examples Must:
- **Compile and run** without modification
- **Use realistic naming** (avoid "Foo", "Bar", generic placeholders)
- **Include complete context** (imports, type definitions, usage)
- **Demonstrate best practices** (proper error handling, testing patterns)

#### Example Structure:
```swift
// Brief comment explaining what this demonstrates
enum RealWorldExample: EffectTransducer {
    // Complete, working implementation
}

// Usage example
let result = RealWorldExample.update(&state, event: .userAction)
```

#### Post-Code Explanations:
- **Highlight key concepts** the code demonstrates
- **Explain non-obvious design decisions**
- **Point out patterns to reuse**
- **Connect to broader architectural principles**

### Tutorial Design Principles

#### Focus and Scope
- **Single concept focus** - each tutorial demonstrates one or a few closely related concepts
- **Resist feature creep** - accept that tutorials will leave audiences wanting more rather than overwhelming them
- **Deliberate incompleteness** - it's better to master fundamentals than superficially cover everything

#### Progressive Tutorial Series
- **Sequential learning paths** - tutorials build upon each other in a logical progression
- **Cumulative knowledge** - later tutorials assume mastery of concepts from earlier ones
- **Explicit prerequisites** - clearly state which tutorials must be completed first
- **Ordered execution** - design tutorials to be completed from first to last in sequence

#### Tutorial Structure
- **Opening (1-2 paragraphs)**: Explain what specific concept this tutorial teaches and why it matters
- **Learning objectives**: What the reader will accomplish by the end
- **Prerequisites**: What knowledge or previous tutorials are assumed
- **Conclusion**: Recap what was learned and bridge to the next logical step

#### Progressive Learning
- **Start with fundamentals** (pure functions, deterministic behavior)
- **Build complexity gradually** (simple transducer → effects → SwiftUI integration)
- **Reinforce previous concepts** as new ones are introduced
- **Provide checkpoints** for learner confidence

#### Interactive Elements
- **Step-by-step code building** with incremental changes visible
- **Executable examples** at each stage
- **Testing sections** showing verification approaches
- **"What you learned" summaries** at key points

#### Real-World Context
- **Use practical examples** (authentication, data loading, form validation)
- **Show complete implementations** rather than fragments
- **Demonstrate testing approaches** for each pattern
- **Connect to actual development challenges**

### Writing Style Guidelines

### Tone and Voice
- **Conversational but authoritative** - explain concepts clearly without being condescending
- **Problem-focused** - start with real developer pain points
- **Solution-oriented** - show how Oak addresses specific challenges
- **Encouraging** - emphasize that FSMs are learnable and beneficial

### Technical Language
- **Explain FSM terminology** when first introduced
- **Use consistent naming** throughout all documentation
- **Prefer concrete examples** over abstract descriptions
- **Define domain-specific terms** in context

### Bullet Point Guidelines
- **Limit bullet lists** to 3-5 points in overviews and introductory sections
- **Avoid overwhelming lists** when introducing new concepts to beginners
- **Prefer progressive disclosure** - introduce concepts gradually rather than listing many at once
- **Use bullets for summaries** rather than initial explanations
- **Interactive contexts allow more bullets** - tutorials can introduce points progressively during hands-on learning

### Code Commentary
- **Explain the "why"** not just the "what"
- **Highlight patterns** that transfer to other scenarios
- **Point out common mistakes** and how to avoid them
- **Connect code to conceptual principles**

## Content Maintenance

### Consistency Checks
- **Verify all code examples compile** with current Oak version
- **Ensure cross-references work** between articles and API docs
- **Maintain consistent terminology** across all content
- **Update examples** when APIs change

### Quality Standards
- **Test all tutorial steps** to ensure they work as documented
- **Validate external links** and update broken references
- **Review for accessibility** (screen reader compatibility, clear structure)
- **Check for completeness** (no missing required parameters, imports, etc.)

## DocC-Specific Guidelines

### Linking Patterns
- **Use typed links** for API references: `` `Effect` ``
- **Use doc links** for articles: `<doc:Effects>`
- **Use tutorial references** for interactive content: `<doc:BuildingYourFirstTransducer>`

### Callout Usage
- **Important**: For critical requirements or safety information
- **Note**: For helpful context or additional information
- **Warning**: For potential pitfalls or breaking changes
- **Tip**: For optimization suggestions or best practices

### Navigation Structure
- **Group related concepts** in logical topics sections
- **Provide clear entry points** for different learning paths
- **Cross-link between** tutorials, articles, and API docs
- **Include "Next Steps"** guidance in tutorials

## AI Collaboration Guidelines

### When Using AI for Documentation
- **Provide clear context** about audience and learning objectives
- **Review generated content** for technical accuracy
- **Ensure examples compile** and follow Oak patterns
- **Maintain consistent voice** across human and AI-generated content

### AI Strengths for DocC
- **Systematic formatting** of API documentation
- **Consistent cross-referencing** between related concepts
- **Example generation** following established patterns
- **Content organization** and structural improvements

### Human Review Required
- **Technical accuracy** of all FSM concepts and implementations
- **Pedagogical effectiveness** of learning progressions
- **Clarity for target audience** (developers new to FSMs)
- **Integration with Oak's philosophy** and design principles

## Success Metrics

### Documentation Effectiveness
- **Developers can successfully** implement their first Oak transducer after reading the tutorial
- **Common questions** are answered in articles before developers need to ask
- **Code examples work** without modification in real projects
- **Learning progression feels natural** from basic to advanced concepts

### Quality Indicators
- **Minimal support requests** for topics covered in documentation
- **Positive developer feedback** about clarity and usefulness
- **Successful framework adoption** by teams following the documentation
- **Consistent patterns** in community-contributed examples