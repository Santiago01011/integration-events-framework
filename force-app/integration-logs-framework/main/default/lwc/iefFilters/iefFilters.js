import { LightningElement, api, wire, track } from "lwc";
import getFilterOptions from "@salesforce/apex/IntegrationHealthController.getFilterOptions";

import IEF_Search_Context from "@salesforce/label/c.IEF_Search_Context";
import IEF_Search_Placeholder from "@salesforce/label/c.IEF_Search_Placeholder";
import IEF_Toggle_Filters from "@salesforce/label/c.IEF_Toggle_Filters";
import IEF_Refresh_Data from "@salesforce/label/c.IEF_Refresh_Data";
import IEF_Correlation_Id from "@salesforce/label/c.IEF_Correlation_Id";
import IEF_Observation_Type from "@salesforce/label/c.IEF_Observation_Type";
import IEF_Integration_Code from "@salesforce/label/c.IEF_Integration_Code";
import IEF_From from "@salesforce/label/c.IEF_From";
import IEF_To from "@salesforce/label/c.IEF_To";
import IEF_Clear_All_Filters from "@salesforce/label/c.IEF_Clear_All_Filters";
import IEF_Search_Help from "@salesforce/label/c.IEF_Search_Help";
import IEF_Updated from "@salesforce/label/c.IEF_Updated";

export default class IefFilters extends LightningElement {
  labels = {
    IEF_Search_Context,
    IEF_Search_Placeholder,
    IEF_Toggle_Filters,
    IEF_Refresh_Data,
    IEF_Correlation_Id,
    IEF_Observation_Type,
    IEF_Integration_Code,
    IEF_From,
    IEF_To,
    IEF_Clear_All_Filters,
    IEF_Search_Help,
    IEF_Updated
  };

  @api lastUpdated;
  @api isLoading = false;
  @track showFilters = false;

  _searchValue = "";
  _observationValue = "";
  _integrationCodeValue = "";
  _correlationValue = "";
  _fromUTC = "";
  _toUTC = "";
  _fromDate = "";
  _fromTime = "";
  _toDate = "";
  _toTime = "";

  observationOptions = [];
  integrationOptions = [];

  @wire(getFilterOptions)
  wiredOptions({ data }) {
    if (data) {
      this.observationOptions = [
        { label: "All Types", value: "" },
        ...data.observationTypes.map((type) => ({ label: type, value: type }))
      ];
      this.integrationOptions = [
        { label: "All Integrations", value: "" },
        ...data.integrationCodes.map((code) => ({ label: code, value: code }))
      ];
    }
  }

  @api get searchValue() {
    return this._searchValue;
  }
  set searchValue(value) {
    this._searchValue = value || "";
  }

  @api get correlationValue() {
    return this._correlationValue;
  }
  set correlationValue(value) {
    this._correlationValue = value || "";
  }

  @api get observationValue() {
    return this._observationValue;
  }
  set observationValue(value) {
    this._observationValue = value || "";
  }

  @api get integrationCodeValue() {
    return this._integrationCodeValue;
  }
  set integrationCodeValue(value) {
    this._integrationCodeValue = value || "";
  }

  @api get fromValue() {
    return this._fromUTC;
  }
  set fromValue(value) {
    this._fromUTC = value || "";
    this.syncFromLocalValue();
  }

  @api get toValue() {
    return this._toUTC;
  }
  set toValue(value) {
    this._toUTC = value || "";
    this.syncToLocalValue();
  }

  get fromDate() {
    return this._fromDate;
  }
  get toDate() {
    return this._toDate;
  }
  get fromTime() {
    return this._fromTime;
  }
  get toTime() {
    return this._toTime;
  }

  handleToggleFilters() {
    this.showFilters = !this.showFilters;
  }

  get filterIcon() {
    return this.showFilters ? "utility:close" : "utility:filterList";
  }

  get filterButtonVariant() {
    return this.showFilters ? "brand" : "neutral";
  }

  handleSearchChange(event) {
    this._searchValue = event.detail.value;
    this.debounceFilter();
  }

  handleObservationChange(event) {
    this._observationValue = event.detail.value;
    this.dispatchFiltersChanged();
  }

  handleIntegrationChange(event) {
    this._integrationCodeValue = event.detail.value;
    this.dispatchFiltersChanged();
  }

  handleCorrelationChange(event) {
    this._correlationValue = event.detail.value;
    this.debounceFilter();
  }

  handleFromDateChange(event) {
    this._fromDate = event.detail.value || "";
    this.updateFromUTCFromParts();
  }

  handleFromTimeChange(event) {
    this._fromTime = event.detail?.value || "";
    this.updateFromUTCFromParts();
  }

  handleToDateChange(event) {
    this._toDate = event.detail.value || "";
    this.updateToUTCFromParts();
  }

  handleToTimeChange(event) {
    this._toTime = event.detail?.value || "";
    this.updateToUTCFromParts();
  }

  handleRefresh() {
    this.dispatchEvent(new CustomEvent("refresh"));
  }

  handleClearFilters() {
    this._searchValue = "";
    this._observationValue = "";
    this._integrationCodeValue = "";
    this._correlationValue = "";
    this._fromUTC = "";
    this._toUTC = "";
    this._fromDate = "";
    this._fromTime = "";
    this._toDate = "";
    this._toTime = "";
    this.dispatchFiltersChanged();
  }

  filterTimeout;
  debounceFilter() {
    window.clearTimeout(this.filterTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.filterTimeout = window.setTimeout(() => {
      this.dispatchFiltersChanged();
    }, 400);
  }

  updateFromUTCFromParts() {
    this._fromUTC = this.convertLocalPartsToUTC(
      this._fromDate,
      this._fromTime,
      "00:00:00"
    );
    this.dispatchFiltersChanged();
  }

  updateToUTCFromParts() {
    this._toUTC = this.convertLocalPartsToUTC(
      this._toDate,
      this._toTime,
      "23:59:59"
    );
    this.dispatchFiltersChanged();
  }

  dispatchFiltersChanged() {
    const filters = {
      search: this._searchValue,
      observationType: this._observationValue,
      integrationCode: this._integrationCodeValue,
      correlationId: this._correlationValue,
      from: this._fromUTC,
      to: this._toUTC
    };
    this.dispatchEvent(new CustomEvent("filterschanged", { detail: filters }));
  }

  convertLocalPartsToUTC(datePart, timePart, defaultTime) {
    if (!datePart) return "";
    const effectiveTime = timePart || defaultTime || "00:00:00";
    const finalTime =
      effectiveTime.length === 5 ? `${effectiveTime}:00` : effectiveTime;

    // Parse as local time by splitting the components
    // This avoids JavaScript's default UTC parsing of ISO strings without timezone
    const [year, month, day] = datePart.split("-").map(Number);
    const [hour, minute, second] = finalTime.split(":").map(Number);
    const local = new Date(year, month - 1, day, hour, minute, second);

    if (isNaN(local.getTime())) return "";
    return local.toISOString();
  }

  syncFromLocalValue() {
    if (!this._fromUTC) {
      this._fromDate = "";
      this._fromTime = "";
      return;
    }

    // Detect if the value is date-only (YYYY-MM-DD) or full ISO datetime
    // Date-only strings like "2026-03-20" should preserve existing time, not convert from UTC
    const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(this._fromUTC);

    if (isDateOnly) {
      // Date-only: preserve existing time or default to midnight
      this._fromDate = this._fromUTC;
      if (!this._fromTime) {
        this._fromTime = "00:00";
      }
      // Rebuild UTC from the preserved time
      this._fromUTC = this.convertLocalPartsToUTC(
        this._fromDate,
        this._fromTime,
        "00:00:00"
      );
      return;
    }

    // Full ISO datetime: parse and extract both date and time
    const local = new Date(this._fromUTC);
    if (isNaN(local.getTime())) {
      this._fromDate = "";
      this._fromTime = "";
      return;
    }
    this._fromDate = this.buildLocalDate(local);
    this._fromTime = this.buildLocalTime(local);
  }

  syncToLocalValue() {
    if (!this._toUTC) {
      this._toDate = "";
      this._toTime = "";
      return;
    }

    // Detect if the value is date-only (YYYY-MM-DD) or full ISO datetime
    // Date-only strings like "2026-03-20" should preserve existing time, not convert from UTC
    const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(this._toUTC);

    if (isDateOnly) {
      // Date-only: preserve existing time or default to end of day
      this._toDate = this._toUTC;
      if (!this._toTime) {
        this._toTime = "23:59";
      }
      // Rebuild UTC from the preserved time
      this._toUTC = this.convertLocalPartsToUTC(
        this._toDate,
        this._toTime,
        "23:59:59"
      );
      return;
    }

    // Full ISO datetime: parse and extract both date and time
    const local = new Date(this._toUTC);
    if (isNaN(local.getTime())) {
      this._toDate = "";
      this._toTime = "";
      return;
    }
    this._toDate = this.buildLocalDate(local);
    this._toTime = this.buildLocalTime(local);
  }

  buildLocalDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  buildLocalTime(date) {
    const hour = String(date.getHours()).padStart(2, "0");
    const minute = String(date.getMinutes()).padStart(2, "0");
    return `${hour}:${minute}`;
  }
}
