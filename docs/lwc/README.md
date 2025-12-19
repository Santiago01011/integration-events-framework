# Integration Health Dashboard - README para Desarrolladores

Este documento es la única fuente de verdad para los desarrolladores que trabajan en el Integration Health Dashboard. Proporciona una descripción general completa de la arquitectura, los componentes, los patrones de implementación clave y los procedimientos operativos.

---

## 1. Descripción General de Alto Nivel

El Integration Health Dashboard es un Componente Web Lightning (LWC) diseñado para proporcionar una vista completa y en tiempo real del estado de los trabajos de integración dentro de Salesforce.

### Características Clave
- **Actualizaciones en Tiempo Real**: Se suscribe al Evento de Plataforma `IntegrationError__e` para actualizar los datos automáticamente.
- **Múltiples Vistas**:
    1.  **Resumen**: Una tarjeta de alto nivel que muestra la salud general de todas las integraciones.
    2.  **Filtros**: Una tabla detallada, con capacidad de búsqueda y filtrado, de todos los registros de integración.
    3.  **Resúmenes por integración**: Una cuadrícula de tarjetas de resumen, una para cada contexto de integración (p. ej., "Facturas", "Productos").
- **Componentes Reutilizables**: Construido con una arquitectura modular centrada en componentes reutilizables como `ihdStatsCard` y `progressBar`.
- **Acciones de Usuario**: Permite a los usuarios ver detalles de los registros, marcarlos como procesados o reabrirlos.

---

## 2. Arquitectura de Componentes

El dashboard se compone de varios componentes clave que trabajan juntos.

```
integrationHealthDashboard (Contenedor Principal)
│
├── Pestaña Resumen
│   └── c-ihd-stats-card (muestra estadísticas generales)
│       └── c-progress-bar
│
├── Pestaña Filtros
│   ├── c-ihd-filters
│   └── c-ihd-table
│
└── Pestaña Resúmenes por integración
    └── c-ihd-integration-summary-card (para cada integración)
        └── c-ihd-stats-card
            └── c-progress-bar
```

### Desglose de Componentes

-   **`integrationHealthDashboard`**: El componente contenedor principal. Gestiona el conjunto de pestañas, orquesta la obtención de datos y maneja la suscripción al Evento de Plataforma.
-   **`ihdStatsCard` (Reutilizable)**: Una tarjeta genérica para mostrar estadísticas. Cuenta con un título, una barra de progreso y una lista configurable de estadísticas. Este es el componente principal para mostrar datos de resumen.
-   **`ihdIntegrationSummaryCard`**: Un componente contenedor que consume un objeto `IntegrationSummary` de Apex y pasa los datos transformados a `c-ihd-stats-card`.
-   **`progressBar` (Reutilizable)**: Una barra de progreso simple y estilizable que muestra los porcentajes de éxito y error.
-   **`ihdFilters` & `ihdTable`**: Componentes para la pestaña "Filtros" que proporcionan la vista detallada de los registros.

---

## 3. Patrones de Implementación Clave y "Gotchas"

Esta sección cubre patrones críticos utilizados en el código que debes entender antes de realizar cambios.

### Caché de Datos y `refreshApex`
-   **Problema**: Los métodos de Apex conectados a componentes con `@AuraEnabled(cacheable=true)` son cacheados por el Lightning Data Service. No volverán a obtener datos automáticamente a menos que sus parámetros cambien.
-   **Solución**: Para forzar una actualización (p. ej., después de un Evento de Plataforma), utilizamos la utilidad `refreshApex`.
    1.  El resultado de la llamada `@wire` se almacena en una propiedad privada (p. ej., `this.wiredSummariesResult`).
    2.  Se llama a `refreshApex(this.wiredSummariesResult)` para forzar una llamada al servidor.
-   **Gotcha**: Siempre aprovisiona una propiedad para almacenar el resultado del `wire` si tienes la intención de actualizarlo imperativamente.

### Actualizaciones en Tiempo Real con `empApi`
-   **Mecanismo**: El dashboard se suscribe al canal `/event/IntegrationError__e` usando `lightning/empApi`.
-   **Lógica de Actualización**: Cuando se recibe un evento, el componente llama a `refreshApex` sobre los resultados de `getRecentLogs`, `getAggregates` y `getIntegrationSummaries` para actualizar todas las partes de la interfaz de usuario.
-   **Gotcha**: Las suscripciones a la EMP API pueden fallar silenciosamente debido a tiempos de espera de sesión. El componente incluye un mecanismo básico de reintento y detección de vencimiento de token para manejar esto.

### Renderizado Condicional (`if:true`)
-   **Problema**: Los componentes de la interfaz de usuario que dependen de datos asíncronos (de `@wire`) pueden renderizarse antes de que los datos estén disponibles, causando errores o mostrando estados vacíos (p. ej., una barra de progreso en 0%).
-   **Solución**: La pestaña "Resumen" utiliza una bandera booleana `aggregatesLoaded`. La interfaz de usuario muestra un spinner hasta que el `wire` de `getAggregates` retorna, luego renderiza el `ihdStatsCard` con los datos correctos.
-   **Gotcha**: Al agregar nuevos elementos de interfaz de usuario que dependen de datos de `wire`, siempre usa una bandera de carga para asegurarte de que los datos estén presentes antes de renderizar.

### Estilos Dinámicos en `progressBar`
-   **Problema**: Usar atributos `style` en línea con enlaces de plantilla (p. ej., `style="width: {myWidth}%"`) puede causar errores de análisis de CSS en LWC.
-   **Solución**: El componente `progressBar` utiliza `renderedCallback` para establecer dinámicamente el ancho de las barras de progreso en sus elementos DOM subyacentes. Esta es una forma más segura y compatible de manejar estilos dinámicos.

---

## 4. Cómo Ejecutar y Probar

Usa los siguientes comandos de SFDX para gestionar el componente.

### Desplegar a una Org
Para una scratch org:
```bash
# Empujar todo el código fuente del proyecto
sfdx force:source:push -u <TU_ALIAS_DE_SCRATCH_ORG>
```
Para una sandbox u organización de producción:
```bash
# Desplegar solo el directorio lwc
sfdx force:source:deploy -p force-app/main/default/lwc -u <TU_ALIAS_DE_ORG>
```
**Importante**: Si modificas `IntegrationHealthController.cls`, despliégalo *antes* de desplegar los componentes LWC que dependen de él.
```bash
sfdx force:source:deploy -p force-app/main/default/classes/IntegrationHealthController.cls -u <TU_ALIAS_DE_ORG>
```

### Ejecutar Pruebas de Apex
Para asegurar que la lógica del backend es sólida:
```bash
sfdx force:apex:test:run -c -r human -u <TU_ALIAS_DE_ORG>
```

---

## 5. Checklist de Entrega y PR

Antes de enviar un Pull Request o entregar el trabajo, asegúrate de que lo siguiente esté completo:

-   [ ] **El Código Funciona**: El componente se carga y funciona correctamente en una organización de destino.
-   [ ] **Las Pruebas Pasan**: Todas las pruebas de Apex relevantes pasan.
-   [ ] **La Actualización en Tiempo Real Funciona**: Un nuevo evento `IntegrationError__e` actualiza correctamente todas las pestañas del dashboard.
-   [ ] **No Hay IDs Hardcodeados**: Todos los IDs, URLs y etiquetas son dinámicos.
-   [ ] **Permisos Verificados**: Si se utilizan nuevas clases de Apex u objetos, se ha creado o actualizado un Conjunto de Permisos.
-   [ ] **Documentación Actualizada**: Este `README.md` está actualizado para reflejar cualquier cambio en la arquitectura, nuevos componentes o "gotchas".
-   [ ] **Código Limpio**: El código está formateado y no hay errores de linting.

