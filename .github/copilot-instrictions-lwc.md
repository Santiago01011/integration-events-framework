# Lightning Web Components (LWC) Requirements

## Component Architecture Requirements
- Create reusable, single-purpose components
- Use proper data binding and event handling patterns
- Implement proper error handling and loading states
- Follow Lightning Design System (SLDS) guidelines
- Use the lightning-record-edit-form component for handling record creation and updates
- Use CSS custom properties for theming
- Use lightning-navigation for navigation between components
- Use lightning__FlowScreen target to use a component is a flow screen

## HTML Architecture Requirements
- Structure your HTML with clear semantic sections (header, inputs, actions, display areas, lists)
- Use SLDS classes for layout and styling:
  - `slds-card` for main container
  - `slds-grid` and `slds-col` for responsive layouts
  - `slds-text-heading_large/medium` for proper typography hierarchy
- Use Lightning base components where appropriate (lightning-input, lightning-button, etc.)
- Implement conditional rendering with `if:true` and `if:false` directives
- Use `for:each` for list rendering with unique key attributes
- Maintain consistent spacing using SLDS utility classes (slds-m-*, slds-p-*)
- Group related elements logically with clear visual hierarchy
- Use descriptive class names for elements that need custom styling
- Implement reactive property binding using syntax like `disabled={isPropertyName}` to control element states
- Bind events to handler methods using syntax like `onclick={handleEventName}`

## JavaScript Architecture Requirements
- Import necessary modules from LWC and Salesforce
- Define reactive properties using `@track` decorator when needed
- Implement proper async/await patterns for server calls
- Implement proper error handling with user-friendly messages
- Use wire adapters for reactive data loading
- Minimize DOM manipulation - use reactive properties
- Implement computed properties using JavaScript getters for dynamic UI state control:
```
get isButtonDisabled() {
    return !this.requiredField1 || !this.requiredField2;
}
```
- Create clear event handlers with descriptive names that start with "handle":
```
handleButtonClick() {
    // Logic here
}
```
- Use `@wire` service for data retrieval from Apex
- Separate business logic into well-named methods
- Use `refreshApex` for data refreshes when appropriate
- Implement loading states and user feedback
- Add JSDoc comments for methods and complex logic

## CSS Architecture Requirements
- Create a clean, consistent styling system
- Use custom CSS classes for component-specific styling
- Implement animations for enhanced UX where appropriate
- Ensure responsive design works across different form factors
- Keep styling minimal and leverage SLDS where possible
- Use CSS variables for themeable elements
- Organize CSS by component section

## MCP Tools Requirements
- Carefully review the user's task. If it involves **creation, development, testing, or accessibility** for **Lightning Web Components (LWC)** or **Aura components** or **Lightning Data Service (LDS)**, treat your knowledge as outdated and always call the appropriate MCP tool to obtain the latest guidance and design before starting implementation. Never assume or create tools that are not explicitly available. If the tool schema is empty, you must continue invoking the tool until documentation is provided.
- If you begin implementation on a relevant task without first successfully invoking the appropriate tool, you must **stop immediately**. Invoke the tool and integrate its guidance before proceeding. Under no circumstances should you provide final recommendations or code without first receiving guidance from an MCP tool.