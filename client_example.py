"""
Calls the deployed finance-insights pipeline on RocketRide Cloud.

Install:
    pip install rocketride

Environment:
    ROCKETRIDE_URI     https://cloud.rocketride.ai   (or ws://localhost:5565 while developing locally)
    ROCKETRIDE_APIKEY  your RocketRide Cloud API token

    The pipeline itself also needs, set wherever you deployed it (RocketRide
    Cloud project settings, or your local .env when running `rocketride start`):
    ANTHROPIC_API_KEY, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD, BUTTERBASE_API_KEY
"""

import asyncio
import os

from rocketride import RocketRideClient


async def ask(question: str) -> str:
    async with RocketRideClient(
        uri=os.environ.get("ROCKETRIDE_URI", "https://cloud.rocketride.ai"),
        auth=os.environ["ROCKETRIDE_APIKEY"],
    ) as client:
        # Runs the pipeline that's already deployed to RocketRide Cloud.
        # Swap filepath for the project_id of a `client.deploy.add(...)` run
        # if you deployed it as a scheduled/on-demand project instead.
        result = await client.use(filepath="finance-insights.pipe")
        token = result["token"]

        response = await client.send(
            token,
            question,
            objinfo={"name": "question.txt"},
            mimetype="text/plain",
        )

        await client.terminate(token)
        return response


async def main():
    questions = [
        "What subscriptions look recurring and how much am I spending on them monthly?",
        "Is there anything unusual in my recent transactions?",
        "Where could I realistically cut spending without losing anything I actually use?",
    ]
    for q in questions:
        print(f"\n> {q}")
        print(await ask(q))


if __name__ == "__main__":
    asyncio.run(main())
