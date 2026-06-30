import { Construct } from "constructs";
import { App, TerraformStack } from "cdktn";
import { CloudflareProvider } from "@cdktn/provider-cloudflare/lib/provider";

class CloudflareStack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new CloudflareProvider(this, "cloudflare", {
      apiToken: process.env.CLOUDFLARE_API_TOKEN ?? "",
    });

    // Resources go here
  }
}

const app = new App();
new CloudflareStack(app, "ebox86-cloudflare");
app.synth();
