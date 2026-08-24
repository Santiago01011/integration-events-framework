/**
 * @description Contract versioning helper for IEF plugin registry.
 * SUPPORTED_MAJOR is the major version the host understands. Minor bumps are additive.
 * Use isCompatible to check whether a row's Contract_Version__c can be loaded.
 */
public with sharing class IEF_PluginContract {
  public static final Integer SUPPORTED_MAJOR = 1;

  /**
   * @description Checks whether a version string is compatible with this host.
   * Compatibility is based on major version equality (e.g. 1.0, 1.1 compatible; 2.0 not).
   * Null/blank values are treated as 1.0 for backwards compatibility.
   * @param version Version string such as "1.0" or numeric value
   * @return True if the major version matches SUPPORTED_MAJOR
   */
  public static Boolean isCompatible(String version) {
    if (String.isBlank(version)) {
      return true;
    }
    String trimmed = version.trim();
    Integer major = parseMajor(trimmed);
    return major == null ? true : major == SUPPORTED_MAJOR;
  }

  /**
   * @description Checks compatibility for a numeric version (e.g. 1.0 from Number field).
   * @param version Numeric contract version
   * @return True if major matches SUPPORTED_MAJOR; null treated as compatible
   */
  public static Boolean isCompatible(Decimal version) {
    if (version == null) {
      return true;
    }
    return version.intValue() == SUPPORTED_MAJOR;
  }

  private static Integer parseMajor(String version) {
    if (String.isBlank(version)) {
      return null;
    }
    String majorPart = version.trim().split('\\.')[0];
    try {
      return Integer.valueOf(majorPart);
    } catch (Exception e) {
      return null;
    }
  }
}
