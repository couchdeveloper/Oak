
# NavigationSplitViewOak Example Requirements

## User Story

**As a user**, I want to view a list of ToDo items in a master-detail interface, so that I can select a ToDo and see its details in a separate pane.

## Problem Statement

Users need a reliable and intuitive interface for browsing and managing ToDo items. The system should provide clear feedback during data loading, handle errors gracefully, and allow users to view details for each ToDo item. The master view will present the list of ToDos, and the detail view will show information about the selected ToDo.

## Acceptance Criteria

### AC-001: Initial Empty State
**Given** the app launches  
**When** the user views the initial screen (parent view)  
**Then** the parent view displays a split interface with a list view and a detail view  
**And** the list view displays an empty state message: “There are no ToDos.”  
**And** the list view provides a primary action button labeled “Create ToDo”  
**And** the detail view displays a placeholder message: “No ToDo selected.”

### AC-002: Creating a New ToDo (Modal Presentation)
**Given** the user taps the “Create ToDo” button in the list view  
**When** the action is triggered  
**Then** the parent view presents a modal sheet (not the list or detail view)  
**And** the modal contains a text input field for the ToDo title  
**And** the modal has a title “New ToDo”  
**And** the modal includes explanatory text “Enter a title for your new ToDo:”  
**And** the modal provides “Cancel” and “Create” buttons  
**And** the “Create” button is disabled when input is empty  
**And** the input field is pre-populated with a default value “Untitled ToDo”  
**And** upon confirmation, the modal dismisses

### AC-003: Loading State
**Given** any asynchronous operation (e.g., loading, saving, fetching details) begins  
**When** the operation is in progress  
**Then** the relevant view displays a loading indicator or overlay with a progress indicator and message (e.g., “Loading…”)  
**And** if applicable, a “Cancel” button is provided to terminate the operation

### AC-004: Successful ToDo List Presentation
**Given** the data loading operation completes successfully  
**When** ToDo data is received  
**Then** the loading overlay dismisses  
**And** the system displays the ToDos in a scrollable master list  
**And** each list item shows an icon and the ToDo’s title  
**And** the list supports standard iOS list interactions (selection, scrolling)

### AC-005: ToDo Selection and Detail View
**Given** the ToDo list is displayed in the list view (with single selection enabled; multiple selection is not allowed)
**When** the user selects a ToDo item in the list view  
**Then** a side effect is invoked to load the selected ToDo’s details (see Oak transducer side effects)  
**And** the detail view shows a loading indicator as described in AC-003 until the effect completes  
**And** when the effect completes, the detail view shows the selected ToDo’s title and description  
**And** if the response is an error, error handling follows AC-006 (the detail view shows an empty state with the error message and a "Retry" button; pressing "Retry" restarts the loading operation)  
**And** the detail view updates immediately when a new ToDo is selected  
**And** if no ToDo is selected, the detail view shows a placeholder message “No ToDo selected.”

### AC-006: Error Handling
**Given** a network or data error occurs during loading, creation, or selection  
**When** the error is detected  
**Then** the system displays an error alert with a relevant message  
**And** the user can dismiss the alert and retry the operation



### AC-008: Sorting ToDo Items
**Given** the ToDo list is displayed in the list view  
**When** the user interacts with the sort control (following Apple Style Guidelines)  
**Then** the list is sorted by creation date or due date, in either ascending or descending order  
**And** the sort order and criteria are visually indicated in the list view  
**And** the sorting interaction follows standard iOS conventions

### AC-009: Saving New or Updated ToDo Item
**Given** a new or updated (in memory) ToDo item has been created in the modal  
**When** the user saves the item  
**Then** a service (side effect) is invoked to persist the ToDo (see Oak transducer side effects)  
**And** the modal shows a loading indicator as described in AC-003 while the save operation is in progress  
**And** the transducer remains in the modal state, only accepting the service response event  
**And** if saving succeeds, the ToDo is added or updated in the list view and the modal dismisses  
**And** if saving fails, error handling follows AC-006
