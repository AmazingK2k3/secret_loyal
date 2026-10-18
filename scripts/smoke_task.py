"""Smallest possible Inspect task, used to prove the install works.

Runs against mockllm (no API key, no spend) by default:

    uv run inspect eval scripts/smoke_task.py --model mockllm/model

M0 also requires one run against a real API model through OpenRouter:

    uv run inspect eval scripts/smoke_task.py --model openrouter/openai/gpt-4o-mini

Then open the log with:  uv run inspect view
"""

from inspect_ai import Task, task
from inspect_ai.dataset import Sample
from inspect_ai.scorer import includes
from inspect_ai.solver import generate


@task
def smoke() -> Task:
    return Task(
        dataset=[
            Sample(
                input="Reply with exactly the word: ready",
                target="ready",
            )
        ],
        solver=generate(),
        scorer=includes(),
    )
