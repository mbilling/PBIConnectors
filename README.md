# Microsoft Power BI Custom Connectors
The Microsoft Power BI custom connector support-project

## Available custom connectors
* [Stripe](#the-stripe-connector)
* [LinkedIn](#the-linkedin-connector)
* [Facebook Pages Insight](#the-facebook-pages-insight-connector)

## The Stripe Connector

The "original" Stripe connector does not return all the data it should so here is a connector that does it right.

## The LinkedIn Connector

This is a connector that access the historical endpoints of linkedin Manage Company Pages endpoints

- Get historical follower statistics about a company
- Get historical status update statistics about a company

Focus is on the granular endpoints since they can be aggregated which play well with Power BI.
We would prefer the raw hit-level data behind each aggregated date but that is not available through the LinkedIn API

## The Facebook Pages Insight Connector

This connector is focused on accessing page insights using the pages insights API: [Facebook Pages Insight][fb_pages_insights]

The built-in Facebook connector provides access to Facebook user profile, not pages or campaign manager ads.

This is how it looks in Power BI:

<img src="https://github.com/mbilling/PBIConnectors/blob/master/img/fb_pages_insights_navigator_shot.PNG" alt="The Facebook Pages Insight Connector in Power BI" title="The Facebook Pages Insight Connector in Power BI"/>


## How to use the custom connectors
(WORK IN PROGRESS)

The code for the 3 connectors has to be compiled into a .mez file. File ending will change to .pqx according to [Microsoft custom connector repo][ms_repo]


[fb_pages_insights]: https://developers.facebook.com/docs/graph-api/reference/page/insights
[fb_pages_insights_navigator_shot]: https://github.com/mbilling/PBIConnectors/blob/master/img/fb_pages_insights_navigator_shot.PNG
[ms_repo]: https://github.com/Microsoft/DataConnectors
