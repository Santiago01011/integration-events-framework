import { LightningElement, wire, track } from "lwc";
import logsApi from "c/utilsLogsApi";
import { refreshApex } from "@salesforce/apex";
import getRegistryInfo from "@salesforce/apex/IntegrationHealthController.getRegistryInfo";
import deployRegistryEntry from "@salesforce/apex/IntegrationHealthController.deployRegistryEntry";
import getRegisteredPlugins from "@salesforce/apex/IntegrationHealthController.getRegisteredPlugins";
import togglePluginEnabled from "@salesforce/apex/IntegrationHealthController.togglePluginEnabled";
import refreshPluginCache from "@salesforce/apex/IntegrationHealthController.refreshPluginCache";

import IHD_Integration_Registry from "@salesforce/label/c.IHD_Integration_Registry";
import IHD_Open_Setup from "@salesforce/label/c.IHD_Open_Setup";
import IHD_Refresh from "@salesforce/label/c.IHD_Refresh";
import IHD_Registration_Coverage from "@salesforce/label/c.IHD_Registration_Coverage";
import IHD_Total from "@salesforce/label/c.IHD_Total";
import IHD_Registered from "@salesforce/label/c.IHD_Registered";
import IHD_Unregistered from "@salesforce/label/c.IHD_Unregistered";
import IHD_Unregistered_Warning from "@salesforce/label/c.IHD_Unregistered_Warning";
import IHD_No_Integrations_Found from "@salesforce/label/c.IHD_No_Integrations_Found";
import IHD_Register_Update_Help from "@salesforce/label/c.IHD_Register_Update_Help";
import IHD_Register_Update from "@salesforce/label/c.IHD_Register_Update";
import IHD_Open_In_Setup from "@salesforce/label/c.IHD_Open_In_Setup";
import IHD_Integration_Code from "@salesforce/label/c.IHD_Integration_Code";
import IHD_Label_Display_Name from "@salesforce/label/c.IHD_Label_Display_Name";
import IHD_Label_Placeholder from "@salesforce/label/c.IHD_Label_Placeholder";
import IHD_Group from "@salesforce/label/c.IHD_Group";
import IHD_Group_Placeholder from "@salesforce/label/c.IHD_Group_Placeholder";
import IHD_Direction from "@salesforce/label/c.IHD_Direction";
import IHD_Transport from "@salesforce/label/c.IHD_Transport";
import IHD_Transport_Placeholder from "@salesforce/label/c.IHD_Transport_Placeholder";
import IHD_Enabled_Kill_Switch from "@salesforce/label/c.IHD_Enabled_Kill_Switch";
import IHD_Enabled_Help from "@salesforce/label/c.IHD_Enabled_Help";
import IHD_Cancel from "@salesforce/label/c.IHD_Cancel";
import IHD_Update from "@salesforce/label/c.IHD_Update";
import IHD_Register from "@salesforce/label/c.IHD_Register";
import IHD_Direction_Inbound from "@salesforce/label/c.IHD_Direction_Inbound";
import IHD_Direction_Outbound from "@salesforce/label/c.IHD_Direction_Outbound";
import IHD_Direction_Bidirectional from "@salesforce/label/c.IHD_Direction_Bidirectional";
import IHD_Column_Status from "@salesforce/label/c.IHD_Column_Status";
import IHD_Column_Label from "@salesforce/label/c.IHD_Column_Label";
import IHD_Column_Enabled from "@salesforce/label/c.IHD_Column_Enabled";
import IHD_Column_Events from "@salesforce/label/c.IHD_Column_Events";
import IHD_Deployment_Started from "@salesforce/label/c.IHD_Deployment_Started";
import IHD_Deployment_Message from "@salesforce/label/c.IHD_Deployment_Message";

const COLUMNS = [
  {
    label: IHD_Column_Status,
    fieldName: "statusIcon",
    type: "text",
    initialWidth: 80,
    cellAttributes: {
      iconName: { fieldName: "statusIconName" },
      iconAlternativeText: { fieldName: "statusLabel" }
    }
  },
  { label: IHD_Integration_Code, fieldName: "integrationCode", type: "text" },
  {
    label: IHD_Column_Label,
    fieldName: "label",
    type: "text"
  },
  {
    label: IHD_Group,
    fieldName: "groupName",
    type: "text"
  },
  {
    label: IHD_Direction,
    fieldName: "direction",
    type: "text"
  },
  {
    label: IHD_Transport,
    fieldName: "transport",
    type: "text"
  },
  {
    label: IHD_Column_Enabled,
    fieldName: "isEnabled",
    type: "boolean",
    initialWidth: 90
  },
  {
    label: IHD_Column_Events,
    fieldName: "eventCount",
    type: "number",
    initialWidth: 90
  },
  {
    type: "action",
    typeAttributes: {
      rowActions: [
        { label: IHD_Register_Update, name: "register" },
        { label: IHD_Open_In_Setup, name: "open_setup" }
      ]
    }
  }
];

export default class IhdAdminPanel extends LightningElement {
  labels = {
    IHD_Integration_Registry,
    IHD_Open_Setup,
    IHD_Refresh,
    IHD_Registration_Coverage,
    IHD_Total,
    IHD_Registered,
    IHD_Unregistered,
    IHD_Unregistered_Warning,
    IHD_No_Integrations_Found,
    IHD_Register_Update_Help,
    IHD_Register_Update,
    IHD_Open_In_Setup,
    IHD_Integration_Code,
    IHD_Label_Display_Name,
    IHD_Label_Placeholder,
    IHD_Group,
    IHD_Group_Placeholder,
    IHD_Direction,
    IHD_Transport,
    IHD_Transport_Placeholder,
    IHD_Enabled_Kill_Switch,
    IHD_Enabled_Help,
    IHD_Cancel,
    IHD_Update,
    IHD_Register,
    IHD_Deployment_Started,
    IHD_Deployment_Message
  };

  // Direction options with labels
  directionOptions = [
    { label: IHD_Direction_Inbound, value: "Inbound" },
    { label: IHD_Direction_Outbound, value: "Outbound" },
    { label: IHD_Direction_Bidirectional, value: "Bidirectional" }
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
    console.log("handleTogglePlugin called:", {
      developerName,
      enabled,
      targetType: typeof enabled
    });
    try {
      console.log("Calling refreshPluginCache...");
      await refreshPluginCache();

      console.log("Calling togglePluginEnabled with:", {
        developerName,
        enabled: !enabled
      });
      const result = await togglePluginEnabled({
        developerName: developerName,
        enabled: !enabled
      });

      console.log("togglePluginEnabled result:", result);
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
    window.open("/lightning/setup/CustomMetadata/home", "_blank");
  }
}
