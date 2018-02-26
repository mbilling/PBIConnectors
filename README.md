# Microsoft Power BI Custom Connectors
The Microsoft Power BI custom connector support-project

## Available custom connectors
* [Stripe](#the-stripe-connector)
* [LinkedIn](#the-linkedin-connector)
* [Facebook Pages Insight](#the-facebook-pages-insight-connector)

## The Stripe Connector

The "original" Stripe connector does not return all the data it should so here is a connector that does it right.

## The LinkedIn Connector

To build the connector you need to create a Linked In App to get an OAuth2 key and secret.
[Create a the app here][li-api]

In LinkedIn\WebApp.json set Client Id and Client Secret
```
      "client_id": "[Client ID]",
      "client_secret": "[Client Secret]",
```

The connector is an interface to historical endpoints of linkedin Manage Company Pages endpoints

- Get historical follower statistics about a company
- Get historical status update statistics about a company

Focus is on the granular endpoints since they can be aggregated which play well with Power BI.
We would prefer the raw hit-level data behind each aggregated date but that is not available through the LinkedIn API

This is how it looks in Power BI:

<img src="https://github.com/mbilling/PBIConnectors/blob/master/img/linkedin-company-navigator-shot.png" alt="The LinkedIn Connector in Power BI" title="The LinkedIn Connector in Power BI"/>

## The Facebook Pages Insight Connector

To build the connector you need to create a Facebook App to get an OAuth2 key and secret.
[Create a the app here][fb-api]

In FacebookPages\WebApp.json set Client Id and Client Secret
```
      "client_id": "[App ID]",
      "client_secret": "[App Secret]",
```

This connector is focused on accessing page insights using the pages insights API: [Facebook Pages Insight][fb_pages_insights]

The built-in Facebook connector provides access to Facebook user profile, not pages or campaign manager ads.

This is how it looks in Power BI:

<img src="https://github.com/mbilling/PBIConnectors/blob/master/img/fb_pages_insights_navigator_shot.PNG" alt="The Facebook Pages Insight Connector in Power BI" title="The Facebook Pages Insight Connector in Power BI"/>


## How to use the custom connectors
Microsoft only supports custom connectors for Power BI Desktop. We expect this to change when they release the Power Query SDK.

Using the connectors
1. When custom connectors are built into .mez files, they should be copied to Documents\Microsoft Power BI Desktop\Custom Connectors
2. Start Power BI
3. Ooen the Options dialog
4. Select Preview features and Click OK
5. Click Get Data and select Other
6. You find the Connectors here.

## Related repos
[Facebook Ads Connector][hugo]
[Youtube Connector][miguel]


[fb_pages_insights]: https://developers.facebook.com/docs/graph-api/reference/page/insights
[fb_pages_insights_navigator_shot]: https://github.com/mbilling/PBIConnectors/blob/master/img/fb_pages_insights_navigator_shot.PNG
[ms_repo]: https://github.com/Microsoft/DataConnectors
[hugo]: https://github.com/Hugoberry/FacebookAds
[miguel]: https://github.com/migueesc123/YoutubeAnalytics
[li-api]: https://www.linkedin.com/developer/apps
[fb-api]: https://developers.facebook.com/apps/