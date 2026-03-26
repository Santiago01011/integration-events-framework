import { LightningElement, api } from "lwc";
export default class IefPluginCard extends LightningElement {
  @api title = "";
  @api isLoading = false;
  @api hasError = false;
  @api errorMessage = "";
  @api hasData = false;
  @api emptyText = "";
  @api loadingVariant = "donut";
  @api clickable = true;
  @api ariaLabel = "";
}
