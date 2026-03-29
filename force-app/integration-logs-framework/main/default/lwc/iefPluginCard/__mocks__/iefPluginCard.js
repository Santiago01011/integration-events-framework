import { LightningElement, api } from "lwc";

export default class IefPluginCardMock extends LightningElement {
  @api title = "";
  @api isLoading = false;
  @api hasError = false;
  @api errorMessage = "";
  @api hasData = false;
  @api emptyText = "";
  @api loadingVariant = "donut";
  @api clickable = false;
  @api ariaLabel = "";
}
