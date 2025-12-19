/**
 * @description Utility methods for data integrations.
 */
@SuppressWarnings('PMD.AvoidDebugStatements')
public without sharing class IntegrationUtils {
  /**
   * @description Convierte un valor en formato yyyy-MM-dd a Date.
   * @param obj Valor a convertir (String/Decimal/etc.).
   * @return Fecha o null si no es posible convertir.
   */
  public static Date toDate(Object obj) {
    if (obj == null) {
      return null;
    }
    String dateStr = String.valueOf(obj);
    if (String.isBlank(dateStr) || !dateStr.contains('-')) {
      return null;
    }
    try {
      List<String> parts = dateStr.split('-');
      if (parts.size() == 3) {
        return Date.newInstance(
          Integer.valueOf(parts[0]),
          Integer.valueOf(parts[1]),
          Integer.valueOf(parts[2])
        );
      }
    } catch (Exception e) {
      return null;
    }
    return null;
  }

  /**
   * @description Convierte a Double de forma segura.
   * @param obj Valor a convertir.
   * @return Double o null.
   */
  public static Double toDouble(Object obj) {
    if (obj == null) {
      return null;
    }
    try {
      return Double.valueOf(String.valueOf(obj));
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * @description Convierte a Decimal de forma segura.
   * @param obj Valor a convertir.
   * @return Decimal o null.
   */
  public static Decimal toDecimal(Object obj) {
    if (obj == null) {
      return null;
    }
    try {
      return Decimal.valueOf(String.valueOf(obj));
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * @description Convierte un valor a Datetime.
   * @param obj Valor a convertir.
   * @return Datetime o null.
   */
  public static Datetime toDateTime(Object obj) {
    Date d = toDate(obj);
    if (d == null) {
      return null;
    }
    return Datetime.newInstance(d.year(), d.month(), d.day());
  }

  /**
   * @description Convierte valores de fecha y hora a Datetime combinado.
   * @param dateVal Valor de fecha.
   * @param timeVal Valor de hora.
   * @return Datetime combinado o null.
   */
  public static DateTime toDateTimeWithTime(Object dateVal, Object timeVal) {
    if (dateVal == null) {
      return null;
    }
    Date d = toDate(dateVal);
    if (d == null) {
      return null;
    }

    // If time is provided, combine date and time
    if (timeVal != null && !String.isBlank(String.valueOf(timeVal))) {
      try {
        String timeStr = String.valueOf(timeVal);
        List<String> timeParts = timeStr.split(':');
        if (timeParts.size() >= 2) {
          Integer hours = Integer.valueOf(timeParts[0]);
          Integer minutes = Integer.valueOf(timeParts[1]);
          Integer seconds = timeParts.size() > 2
            ? Integer.valueOf(timeParts[2])
            : 0;
          return DateTime.newInstance(
            d.year(),
            d.month(),
            d.day(),
            hours,
            minutes,
            seconds
          );
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.WARN,
          'Failed to parse time component: ' + timeVal
        );
      }
    }

    // If no time or parsing failed, return date at midnight
    return DateTime.newInstance(d.year(), d.month(), d.day());
  }

  /**
   * @description Convierte un valor a Time.
   * @param val Valor a convertir.
   * @return Time o null.
   */
  public static Time toTime(Object val) {
    if (val == null || String.isBlank(String.valueOf(val))) {
      return null;
    }
    try {
      String timeStr = String.valueOf(val);
      List<String> timeParts = timeStr.split(':');
      if (timeParts.size() >= 2) {
        Integer hours = Integer.valueOf(timeParts[0]);
        Integer minutes = Integer.valueOf(timeParts[1]);
        Integer seconds = timeParts.size() > 2
          ? Integer.valueOf(timeParts[2])
          : 0;
        return Time.newInstance(hours, minutes, seconds, 0);
      }
      return null;
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'Failed to parse Time: ' + val);
      return null;
    }
  }

  /**
   * @description Mapea el estado del documento de SAP al campo de estado del Pedido.
   * @param docStatus Código de estado del documento (p.ej. 'C', 'O', 'A').
   * @return Valor en español para Order.Status.
   */
  public static String mapDocumentStatus(String docStatus) {
    if ('C'.equals(docStatus)) {
      return 'Cerrado';
    }
    if ('O'.equals(docStatus)) {
      return 'Abierto';
    }
    if ('A'.equals(docStatus)) {
      return 'Borrador';
    }
    System.debug(
      LoggingLevel.WARN,
      'Unknown DocumentStatus "' + docStatus + '", defaulting to Borrador'
    );
    return 'Borrador';
  }

  /**
   * @description Mapea valor de receta a SI/NO.
   * @param receta Valor de U_Receta.
   * @return 'SI' o 'NO'.
   */
  public static String mapReceta(String receta) {
    return 'Y'.equals(receta) ? 'SI' : 'NO';
  }

  /**
   * @description Valida si un valor es permitido para un campo lista de selección.
   * @param objectName API name of the SObject.
   * @param fieldName API name of the field.
   * @param value Value to validate.
   * @return true if valid or empty, false otherwise.
   */
  public static Boolean isValidPicklistValue(
    String objectName,
    String fieldName,
    String value
  ) {
    if (String.isBlank(value)) {
      return true;
    }
    try {
      Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe()
        .get(objectName)
        .getDescribe()
        .fields.getMap()
        .get(fieldName)
        .getDescribe();
      if (fieldResult.getType() == Schema.DisplayType.PICKLIST) {
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
          if (entry.getValue() == value) {
            return true;
          }
        }
      }
      return false;
    } catch (Exception e) {
      return false;
    }
  }
}
