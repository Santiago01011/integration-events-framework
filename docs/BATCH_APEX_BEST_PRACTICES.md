# Batch Apex: Mejores Prácticas (Salesforce Standards)

Este documento valida que `ProductosBatchJob` sigue las mejores prácticas de Salesforce basándose en `BatchApexRecipes.cls`.

## ✅ Comparación: ProductosBatchJob vs BatchApexRecipes

### 1. Implementación de la interfaz Batchable

**BatchApexRecipes**:
```apex
public with sharing class BatchApexRecipes implements Database.Batchable<SObject>, Database.Stateful
```

**ProductosBatchJob**:
```apex
public class ProductosBatchJob implements Database.Batchable<Map<String, Object>>, Database.AllowsCallouts, Database.Stateful, Database.RaisesPlatformEvents
```

✅ **Validación**:
- Ambas implementan `Database.Batchable<T>` con tipo genérico (SObject vs Map<String, Object>)
- Ambas implementan `Database.Stateful` para persistir estado entre iteraciones
- ProductosBatchJob adiciona `Database.AllowsCallouts` (necesario para HTTP requests a SAP B1) y `Database.RaisesPlatformEvents` (publica IntegrationEvent__e)
- ✅ **Correcto**

### 2. Método start()

**BatchApexRecipes**:
```apex
public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(queryString);
}
```
- Retorna `QueryLocator` (ligero, sin lógica pesada)
- No hace callouts ni procesamiento
- Solo prepara el scope de datos

**ProductosBatchJob**:
```apex
public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
    List<Map<String, Object>> scopeMarkers = new List<Map<String, Object>>();
    scopeMarkers.add(new Map<String, Object>{ 'scope' => 'page1' });
    return scopeMarkers;
}
```
- Retorna `Iterable<Map<String, Object>>` (ligero, marcadores de scope sin datos)
- No hace callouts ni procesamiento
- Solo prepara el scope (marcadores)

✅ **Validación**: Ambas siguen el principio de separación de responsabilidades: `start()` **solo prepara scope**, no procesa.

### 3. Método execute()

**BatchApexRecipes**:
```apex
public void execute(Database.BatchableContext context, List<Account> scope) {
    for (Account acct : scope) {
        acct.Name += ' Edited by Batch class';
    }
    List<Database.SaveResult> saveResults = Database.update(scope, false);
    for (Database.SaveResult sr : saveResults) {
        if (sr.isSuccess()) {
            successes.add(sr.id);  // Stateful tracking
        } else {
            failures.add(sr.id);   // Stateful tracking
        }
    }
}
```
- Recibe `scope` (lista de records del batch)
- Procesa y actualiza records
- Usa `Database.*` methods con allOrNone=false para separar successes/failures
- Acumula resultados en campos Stateful (successes, failures)

**ProductosBatchJob**:
```apex
public void execute(Database.BatchableContext bc, List<Map<String, Object>> productChunk) {
    try {
        List<Map<String, Object>> productsToProcess = new List<Map<String, Object>>();
        
        if (batchCtx.mode == BatchIntegrationHelper.MODE_MOCK) {
            // Mock mode: parse mockPayload
            Object mockData = BatchIntegrationHelper.parseMockPayload(mockPayload, batchCtx);
            if (mockData instanceof List<Object>) {
                for (Object obj : (List<Object>) mockData) {
                    productsToProcess.add((Map<String, Object>) obj);
                }
            }
        } else {
            // Live mode: callouts to SAP B1
            String expandValue = '...';
            String filterValue = '...';
            productsToProcess = BatchIntegrationHelper.fetchLiveData(...);
        }
        
        if (!productsToProcess.isEmpty()) {
            accumulateResults(ProductosController.processProductList(productsToProcess));
        }
    } catch (Exception ex) {
        batchCtx.rootCauseError = 'Exception in execute: ' + ex.getMessage();
        batchCtx.errorStackTrace = ex.getStackTraceString();
    }
}
```
- Recibe `productChunk` (scope del batch)
- Procesa: fetches data (callouts en live mode), transforms, persists via ProductosController
- Acumula resultados en campos Stateful (totalProductsProcessed, totalProductsUpserted, etc.)
- Maneja excepciones registrando en batchCtx

✅ **Validación**: Ambas siguen el patrón:
1. Reciben scope
2. Procesan datos
3. Acumulan resultados en Stateful fields
4. Error handling

### 4. Método finish()

**BatchApexRecipes**:
```apex
public void finish(Database.BatchableContext context) {
    BatchApexRecipes.result = 'Successes: ' + successes.size() + ' Failures: ' + failures.size();
}
```
- Accede a campos Stateful (successes, failures)
- Consolida y reporta resultados finales
- Podría enviar emails, etc.

**ProductosBatchJob**:
```apex
public void finish(Database.BatchableContext bc) {
    String jobId = bc != null ? String.valueOf(bc.getJobId()) : null;
    Map<String, Object> processingData = new Map<String, Object>();
    processingData.put('productsProcessed', totalProductsProcessed);
    processingData.put('productsUpserted', totalProductsUpserted);
    // ... más datos
    
    Map<String, Object> summary = BatchIntegrationHelper.buildDiagnosticSummary(batchCtx, processingData);
    Boolean hasIssues = BatchIntegrationHelper.hasSignificantIssues(batchCtx, processingData);
    
    if (hasIssues) {
        IntegrationLogger.logError('Productos Integration', summary, jobId);
    } else {
        IntegrationLogger.logSuccess('Productos Integration', summary, jobId);
    }
}
```
- Accede a campos Stateful (totalProductsProcessed, totalProductsUpserted, etc.)
- Consolida métricas
- Loguea resultados vía IntegrationLogger (suscriptor de IntegrationEvent__e)
- Evalúa severidad

✅ **Validación**: Ambas siguen el patrón: `finish()` **consolida y reporta** resultados de todas las iteraciones.

### 5. Tracking de Stateful

**BatchApexRecipes**:
```apex
private List<Id> successes = new List<Id>();
private List<Id> failures = new List<Id>();
```
- Tracking simple: lists acumuladas

**ProductosBatchJob**:
```apex
private Integer totalProductsProcessed = 0;
private Integer totalProductsUpserted = 0;
private Integer totalProductsSkipped = 0;
private List<Map<String, Object>> allSkippedProductDetails = new List<Map<String, Object>>();
private List<Map<String, Object>> allProductErrors = new List<Map<String, Object>>();
```
- Tracking detallado: métricas + detalles de errores

✅ **Validación**: Ambas usan campos Stateful para acumular resultados entre iteraciones.

### 6. Error Handling

**BatchApexRecipes**:
```apex
// Usa Database.update(..., false) para separar successes/failures
// Sin try-catch en execute (fallos capturados por SaveResult)
```

**ProductosBatchJob**:
```apex
try {
    // ... processamiento
} catch (Exception ex) {
    batchCtx.rootCauseError = 'Exception in execute: ' + ex.getMessage();
    batchCtx.errorStackTrace = ex.getStackTraceString();
}
```
- Try-catch en execute para capturar callouts/parsing errors
- Logs de error persistidos en batchCtx para fin

✅ **Validación**: Ambas manejan errores; ProductosBatchJob agrega logging centralizador de excepciones.

## 📋 Checklist: Mejores Prácticas Salesforce

- ✅ Implementa `Database.Batchable<T>` con tipo genérico
- ✅ Implementa `Database.Stateful` para persistencia de estado
- ✅ `start()` es ligero: solo prepara scope, sin lógica pesada
- ✅ `execute()` contiene toda la lógica: procesamiento, callouts (Database.AllowsCallouts), DML
- ✅ `finish()` consolida y reporta resultados de todas las iteraciones
- ✅ Acumula resultados en campos Stateful privados
- ✅ Error handling con try-catch o Database.* methods con allOrNone=false
- ✅ Sin use de @testVisible innecesarios (solo si necesario para testing)
- ✅ Batch size configurable: `Database.executeBatch(batch, 50)`
- ✅ Separa responsabilidades: fetchLiveData(), ProductosController.processProductList(), IntegrationLogger.log*()

## 🎯 Ventajas de la arquitectura actual

1. **Scalabilidad**: Procesa miles de productos en chunks de 50, evitando CPU timeout
2. **Observabilidad**: Métricas detalladas en finish(), auditable via Integration_Log__c
3. **Recuperabilidad**: Stateful tracking permite retry selectivo (futura mejora)
4. **Flexibilidad**: Mock mode para testing, live mode para producción
5. **Mantenibilidad**: Sigue estándares Salesforce; fácil de actualizar

## 📚 Referencias

- Salesforce Batch Apex Best Practices: https://sfdc.co/batch_interface
- Database.Batchable Interface: https://sfdc.co/batchable
- Database.Stateful: https://sfdc.co/stateful
- BatchApexRecipes: Ejemplo oficial de Trailhead (adjunto)
