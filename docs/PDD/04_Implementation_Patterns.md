# 🛠 04. Implementation Patterns for PDD

To make PDD work in practice, we need patterns that allow our packages to be decoupled from the messy reality of the org.

## 1. The Test Data Factory Pattern

**Problem**: Tests need data. Direct instantiation in tests couples the tests to the environment.
**Solution**: Use a centralized `TestDataFactory` that can be swapped or extended.

### Bad Practice (Coupled)

```apex
// In Package Test
Account a = new Account(Name='Test');
insert a; // Fails if Sandbox has a required field "Industry"
```

### Good Practice (Decoupled)

```apex
// In Package Test
Account a = TestDataFactory.createAccount('Test');
// The implementation details of HOW an account is created are hidden.
```

## 2. The Reference Data Pattern

**Problem**: Hardcoding IDs (like Pricebook IDs) or assuming data exists.
**Solution**: Use a `ReferenceData` class to fetch or create standard records.

```apex
public class ReferenceData {
  public static Id getStandardPricebookId() {
    if (Test.isRunningTest()) {
      return Test.getStandardPricebookId();
    }
    return [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
  }
}
```

## 3. The Service Locator Pattern (Resolver)

**Problem**: The package needs to execute logic that lives in the Org (e.g., Tax Calculation), but the package code cannot "see" or instantiate Org classes directly.
**Solution**: Use a **Resolver** pattern with `Type.forName()` to dynamically load the implementation at runtime.

### Step 1: Define the Interface (Package)

```apex
// In Package
public interface ITaxCalculator {
  Decimal calculateTax(Order o);
}
```

### Step 2: Create the Resolver (Package)

This class finds the implementation without a hard dependency.

```apex
// In Package
public class TaxCalculatorResolver {
    public static ITaxCalculator resolve() {
        // 1. Try to find the Org-specific implementation
        Type t = Type.forName('OrgTaxCalculator');

        // 2. If found, instantiate it
        if (t != null) {
            return (ITaxCalculator) t.newInstance();
        }

        // 3. Fallback to a default "No-Op" implementation
        return new NoOpTaxCalculator();
    }
}

// Default implementation (Package)
public class NoOpTaxCalculator implements ITaxCalculator {
    public Decimal calculateTax(Order o) { return 0; }
}
```

### Step 3: Use it in Service (Package)

```apex
// In Package Service
public class OrderService {
  public void processOrder(Order o) {
    // Resolve usage at runtime - safe for Triggers and stateless execution
    ITaxCalculator taxCalc = TaxCalculatorResolver.resolve();
    Decimal tax = taxCalc.calculateTax(o);

    o.Tax__c = tax;
  }
}
```

### Step 4: Implement in Org (Subscriber)

```apex
// In Org (force-app/main)
// Must be global or public depending on namespace
public class OrgTaxCalculator implements ITaxCalculator {
  public Decimal calculateTax(Order o) {
    // Complex org-specific logic here
    return o.Amount * 0.10; // e.g., 10% tax
  }
}
```

## 4. Feature Flags / Custom Metadata

**Problem**: You want to disable a package feature in Production without deploying code.
**Solution**: Use Custom Metadata Types to control feature flags.

See `idhIntegration_Definition__mdt` in the Integration Framework for a live example of this pattern.
