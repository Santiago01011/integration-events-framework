import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import logsApi from "c/utilsLogsApi";
import { refreshApex } from "@salesforce/apex";
import getRegistryInfo from "@salesforce/apex/IntegrationHealthController.getRegistryInfo";
import deployRegistryEntry from "@salesforce/apex/IntegrationHealthController.deployRegistryEntry";
import getRegisteredPlugins from "@salesforce/apex/IntegrationHealthController.getRegisteredPlugins";
import togglePluginEnabled from "@salesforce/apex/IntegrationHealthController.togglePluginEnabled";
import refreshPluginCache from "@salesforce/apex/IntegrationHealthController.refreshPluginCache";

import IEF_Integration_Registry from "@salesforce/label/c.IEF_Integration_Registry";
import IEF_Open_Setup from "@salesforce/label/c.IEF_Open_Setup";
import IEF_Refresh from "@salesforce/label/c.IEF_Refresh";
import IEF_Registration_Coverage from "@salesforce/label/c.IEF_Registration_Coverage";
import IEF_Total from "@salesforce/label/c.IEF_Total";
import IEF_Registered from "@salesforce/label/c.IEF_Registered";
import IEF_Unregistered from "@salesforce/label/c.IEF_Unregistered";
import IEF_Unregistered_Warning from "@salesforce/label/c.IEF_Unregistered_Warning";
import IEF_No_Integrations_Found from "@salesforce/label/c.IEF_No_Integrations_Found";
import IEF_Register_Update_Help from "@salesforce/label/c.IEF_Register_Update_Help";
import IEF_Register_Update from "@salesforce/label/c.IEF_Register_Update";
import IEF_Open_In_Setup from "@salesforce/label/c.IEF_Open_In_Setup";
import IEF_Integration_Code from "@salesforce/label/c.IEF_Integration_Code";
import IEF_Label_Display_Name from "@salesforce/label/c.IEF_Label_Display_Name";
import IEF_Label_Placeholder from "@salesforce/label/c.IEF_Label_Placeholder";
import IEF_Group from "@salesforce/label/c.IEF_Group";
import IEF_Group_Placeholder from "@salesforce/label/c.IEF_Group_Placeholder";
import IEF_Direction from "@salesforce/label/c.IEF_Direction";
import IEF_Transport from "@salesforce/label/c.IEF_Transport";
import IEF_Transport_Placeholder from "@salesforce/label/c.IEF_Transport_Placeholder";
import IEF_Enabled_Kill_Switch from "@salesforce/label/c.IEF_Enabled_Kill_Switch";
import IEF_Enabled_Help from "@salesforce/label/c.IEF_Enabled_Help";
import IEF_Cancel from "@salesforce/label/c.IEF_Cancel";
import IEF_Update from "@salesforce/label/c.IEF_Update";
import IEF_Register from "@salesforce/label/c.IEF_Register";
import IEF_Direction_Inbound from "@salesforce/label/c.IEF_Direction_Inbound";
import IEF_Direction_Outbound from "@salesforce/label/c.IEF_Direction_Outbound";
import IEF_Direction_Bidirectional from "@salesforce/label/c.IEF_Direction_Bidirectional";
import IEF_Column_Status from "@salesforce/label/c.IEF_Column_Status";
import IEF_Column_Label from "@salesforce/label/c.IEF_Column_Label";
import IEF_Column_Enabled from "@salesforce/label/c.IEF_Column_Enabled";
import IEF_Column_Events from "@salesforce/label/c.IEF_Column_Events";
import IEF_Deployment_Started from "@salesforce/label/c.IEF_Deployment_Started";
import IEF_Deployment_Message from "@salesforce/label/c.IEF_Deployment_Message";

const COLUMNS = [
  {
    label: IEF_Column_Status,
    fieldName: "statusIcon",
    type: "text",
    initialWidth: 80,
    cellAttributes: {
      iconName: { fieldName: "statusIconName" },
      iconAlternativeText: { fieldName: "statusLabel" }
    }
  },
  { label: IEF_Integration_Code, fieldName: "integrationCode", type: "text" },
  {
    label: IEF_Column_Label,
    fieldName: "label",
    type: "text"
  },
  {
    label: IEF_Group,
    fieldName: "groupName",
    type: "text"
  },
  {
    label: IEF_Direction,
    fieldName: "direction",
    type: "text"
  },
  {
    label: IEF_Transport,
    fieldName: "transport",
    type: "text"
  },
  {
    label: IEF_Column_Enabled,
    fieldName: "isEnabled",
    type: "boolean",
    initialWidth: 90
  },
  {
    label: IEF_Column_Events,
    fieldName: "eventCount",
    type: "number",
    initialWidth: 90
  },
  {
    type: "action",
    typeAttributes: {
      rowActions: [
        { label: IEF_Register_Update, name: "register" },
        { label: IEF_Open_In_Setup, name: "open_setup" }
      ]
    }
  }
];

export default class IefAdminPanel extends NavigationMixin(LightningElement) {
  labels = {
    IEF_Integration_Registry,
    IEF_Open_Setup,
    IEF_Refresh,
    IEF_Registration_Coverage,
    IEF_Total,
    IEF_Registered,
    IEF_Unregistered,
    IEF_Unregistered_Warning,
    IEF_No_Integrations_Found,
    IEF_Register_Update_Help,
    IEF_Register_Update,
    IEF_Open_In_Setup,
    IEF_Integration_Code,
    IEF_Label_Display_Name,
    IEF_Label_Placeholder,
    IEF_Group,
    IEF_Group_Placeholder,
    IEF_Direction,
    IEF_Transport,
    IEF_Transport_Placeholder,
    IEF_Enabled_Kill_Switch,
    IEF_Enabled_Help,
    IEF_Cancel,
    IEF_Update,
    IEF_Register,
    IEF_Deployment_Started,
    IEF_Deployment_Message
  };

  // Direction options with labels
  directionOptions = [
    { label: IEF_Direction_Inbound, value: "Inbound" },
    { label: IEF_Direction_Outbound, value: "Outbound" },
    { label: IEF_Direction_Bidirectional, value: "Bidirectional" }
  ];

  @track registryData = [];
  @track plugins = [];
  @track error;
  @track filterType = "all";
  @track isLoading = false;
  @track pluginsLoading = false;
  @track showEditModal = false;
  @track editRecord = {};

  columns = COLUMNS;
  wiredResult;

  connectedCallback() {
    this.loadPlugins();
  }

  async loadPlugins() {
    this.pluginsLoading = true;
    try {
      const rawPlugins = await getRegisteredPlugins();
      this.plugins = rawPlugins.map((p) => ({
        ...p,
        toggleLabel: p.enabled ? "Disable" : "Enable",
        toggleTitle: p.enabled
          ? `Disable ${p.label || p.developerName}`
          : `Enable ${p.label || p.developerName}`,
        toggleVariant: p.enabled ? "neutral" : "brand",
        toggleIcon: p.enabled ? "utility:ban" : "utility:check"
      }));
    } catch (e) {
      this.plugins = [];
      const msg = e?.body?.message || e?.message || "Failed to load plugins";
      console.error("loadPlugins error:", msg);
      logsApi.showToast(this, "Plugin Load Error", msg, "error");
    } finally {
      this.pluginsLoading = false;
    }
  }
  handleRefreshPlugins() {
    this.loadPlugins();
  }

  async handleTogglePlugin(event) {
    const developerName = event.currentTarget.dataset.name;
    const enabled = event.currentTarget.dataset.enabled === "true";
    try {
      await refreshPluginCache();

      const result = await togglePluginEnabled({
        developerName: developerName,
        enabled: !enabled
      });
      if (result === null) {
        logsApi.showToast(
          this,
          "Toggle Error",
          `Failed to ${enabled ? "disable" : "enable"} plugin "${developerName}". Check debug logs for details.`,
          "error"
        );
        return;
      }
      logsApi.showToast(
        this,
        "Plugin Updated",
        `${developerName} ${!enabled ? "enabled" : "disabled"}. Deployment in progress...`,
        "success"
      );
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        this.loadPlugins();
      }, 5000);
    } catch (e) {
      console.error("handleTogglePlugin error:", e);
      const msg = e?.body?.message || e?.message || "Failed to toggle plugin";
      logsApi.showToast(this, "Toggle Error", msg, "error");
    }
  }

  get registeredPluginCount() {
    return this.plugins.length;
  }

  @wire(getRegistryInfo)
  wiredRegistry(result) {
    this.wiredResult = result;
    if (result.data) {
      this.registryData = result.data.map((entry) => ({
        ...entry,
        statusIcon: entry.isRegistered ? "" : "",
        statusIconName: entry.isRegistered
          ? entry.isEnabled
            ? "utility:success"
            : "utility:ban"
          : "utility:warning",
        statusLabel: entry.isRegistered
          ? entry.isEnabled
            ? "Registered & Enabled"
            : "Registered & Disabled"
          : "Unregistered"
      }));
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error;
      this.registryData = [];
    }
  }

  get filteredData() {
    if (this.filterType === "unregistered") {
      return this.registryData.filter((entry) => !entry.isRegistered);
    } else if (this.filterType === "registered") {
      return this.registryData.filter((entry) => entry.isRegistered);
    }
    return this.registryData;
  }

  get registeredCount() {
    return this.registryData.filter((entry) => entry.isRegistered).length;
  }

  get unregisteredCount() {
    return this.registryData.filter((entry) => !entry.isRegistered).length;
  }

  get totalCount() {
    return this.registryData.length;
  }

  get hasUnregistered() {
    return this.unregisteredCount > 0;
  }

  get registrationPercentage() {
    return this.totalCount > 0
      ? Math.round((this.registeredCount / this.totalCount) * 100)
      : 0;
  }

  get unregisteredPercentage() {
    return this.totalCount > 0 ? 100 - this.registrationPercentage : 0;
  }

  get modalTitle() {
    return this.editRecord.isRegistered
      ? `Update: ${this.editRecord.integrationCode}`
      : `Register: ${this.editRecord.integrationCode}`;
  }

  get saveButtonLabel() {
    return this.editRecord.isRegistered ? "Update" : "Register";
  }

  handleFilterSelection(event) {
    this.filterType = event.currentTarget.dataset.type;
  }

  get isAllSelected() {
    return this.filterType === "all";
  }

  get isRegisteredSelected() {
    return this.filterType === "registered";
  }

  get isUnregisteredSelected() {
    return this.filterType === "unregistered";
  }

  handleRefresh() {
    this.isLoading = true;
    refreshApex(this.wiredResult).finally(() => {
      this.isLoading = false;
    });
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    switch (actionName) {
      case "register":
        this.openEditModal(row);
        break;
      case "open_setup":
        this.handleOpenSetup();
        break;
      default:
        break;
    }
  }

  openEditModal(row) {
    this.editRecord = {
      integrationCode: " " + row.integrationCode,
      label: row.label || row.integrationCode,
      groupName: row.groupName || "",
      direction: row.direction || "Outbound",
      transport: row.transport || "",
      isEnabled: row.isEnabled !== false,
      isRegistered: row.isRegistered
    };
    this.showEditModal = true;
  }

  handleCloseModal() {
    this.showEditModal = false;
    this.editRecord = {};
  }

  handleLabelChange(event) {
    this.editRecord = { ...this.editRecord, label: event.target.value };
  }

  handleGroupChange(event) {
    this.editRecord = { ...this.editRecord, groupName: event.target.value };
  }

  handleDirectionChange(event) {
    this.editRecord = { ...this.editRecord, direction: event.detail.value };
  }

  handleEnabledChange(event) {
    this.editRecord = { ...this.editRecord, isEnabled: event.target.checked };
  }

  handleTransportChange(event) {
    this.editRecord = { ...this.editRecord, transport: event.target.value };
  }

  async handleSaveRegistration() {
    this.isLoading = true;
    try {
      const jobId = await deployRegistryEntry({
        integrationCode: this.editRecord.integrationCode,
        label: this.editRecord.label,
        groupName: this.editRecord.groupName,
        direction: this.editRecord.direction,
        transport: this.editRecord.transport,
        isEnabled: this.editRecord.isEnabled
      });

      logsApi.showToast(
        this,
        "Deployment Started",
        `Registration submitted (Job ID: ${jobId}). The metadata will be available in a few seconds.`,
        "success"
      );

      this.showEditModal = false;
      this.editRecord = {};

      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        this.handleRefresh();
      }, 3000);
    } finally {
      this.isLoading = false;
    }
  }

  handleOpenSetup() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: "/lightning/setup/CustomMetadata/home"
      }
    });
  }
}
