# TimeClockPicker (LWC)

A **custom time picker Lightning Web Component** that provides an interactive clock-based UI for selecting time, designed for Salesforce environments where native time inputs are either limited or insufficient for advanced UX requirements.

This component is built **from scratch**, without relying on standard `<lightning-input type="time">`, in order to support:

* Clock-style selection
* Drag interactions
* Keyboard navigation
* 12h / 24h modes
* Consistent behavior across Salesforce runtimes

---

## Why this component exists

Salesforce provides basic time inputs, but they lack:

* Visual clock-based selection
* Fine-grained UX control
* Drag-to-select interactions
* Custom validation and formatting logic

This component explores how far **custom UI logic** can go inside LWC while still respecting Salesforce constraints (Shadow DOM, event model, styling limits).

---

## Features

* 🕒 **Clock face time selection**
* 🖱️ **Click & drag interaction** (hour and minute selection)
* ⌨️ **Full keyboard support**

  * Enter to commit
  * Escape to close
* 🌓 **12-hour and 24-hour modes**
* 🔁 **AM / PM toggle** (12h mode)
* 🕰️ **Minute snapping** (5-minute intervals)
* 📐 **Dynamic hand rotation** with smooth angle normalization
* 📱 **Viewport-aware popover placement** (auto flip)
* ✅ **Salesforce-style validation** (`checkValidity`, `reportValidity`)
* 🔔 **Change event dispatching** compatible with forms and parent components

---

## Component API

### Public Properties (`@api`)

```js
@api label        // String - Input label
@api required     // Boolean - Marks field as required
@api disabled     // Boolean - Disables interaction
@api hourMode     // Number - 12 or 24 (default: 24)
@api value        // String - "HH:mm"
```

Example:

```html
<c-time-clock-picker
    label="Start Time"
    required
    hour-mode="24"
    value="08:30">
</c-time-clock-picker>
```

---

## Events

### `change`

Dispatched when the user applies or clears a value.

```js
event.detail.value // "HH:mm" or empty string
```

Example:

```html
<c-time-clock-picker onchange={handleTimeChange}></c-time-clock-picker>
```

```js
handleTimeChange(event) {
    const time = event.detail.value;
    console.log(time); // "14:05"
}
```

---

## Keyboard Interaction

When the popover is open:
* **Enter**

  * Commits the value
* **Escape**

  * Closes the popover

---

## Drag Interaction Model

* Mouse down on the clock face enables drag mode
* Angle and distance from center are continuously calculated
* For 24h mode:
  * Inner ring → 13–23
  * Outer ring → 1–12
* On mouse release:
  * Value is committed
  * Stage advances automatically (hour → minute)

---

## Validation Behavior

The component integrates with Salesforce form validation patterns:

```js
@api checkValidity()
@api reportValidity()
```

* `required` is respected
* Invalid manual input triggers native validation UI
* Validation messages are Salesforce-consistent

---

## Styling & SLDS Integration

* Uses **SLDS utility classes** where possible
* Custom CSS is scoped to the component
* Clock layout is fully responsive
* No global styles or DOM leakage

---

## Design Notes (Developer-Oriented)

* Logic is intentionally kept inside a single LWC to respect framework boundaries
* Geometry calculations (angles, distances, rotation smoothing) are handled manually
* No external libraries
* No DOM queries outside the component template

This is not a wrapper — it is a **full custom interaction component**.

---

## Example Use Cases

* Custom scheduling UI
* Appointment configuration
* Time-based filters

---

## Screenshots / Demo


