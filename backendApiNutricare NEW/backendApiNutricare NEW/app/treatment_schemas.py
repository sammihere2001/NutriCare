"""Medication records are descriptive; these schemas never prescribe doses."""
from datetime import date
from enum import Enum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MedicationClass(str, Enum):
    insulin = "insulin"
    glp1 = "glp1"
    dual_gip_glp1 = "dual_gip_glp1"
    metformin = "metformin"
    sglt2 = "sglt2"
    sulfonylurea = "sulfonylurea"
    meglitinide = "meglitinide"
    dpp4 = "dpp4"
    thiazolidinedione = "thiazolidinedione"
    alpha_glucosidase = "alpha_glucosidase"
    other = "other"


class MedicationRecord(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    medication_class: MedicationClass
    name: str = Field("", max_length=100)
    prescribed_dose: str = Field("", max_length=100)
    schedule: str = Field("", max_length=150)
    started_on: date | None = None

    @field_validator("started_on")
    @classmethod
    def no_future_start(cls, value):
        if value is not None and value > date.today():
            raise ValueError("Start date cannot be in the future")
        return value


class TreatmentProfile(BaseModel):
    model_config = ConfigDict(extra="forbid")
    medications_confirmed: bool = False
    medications: list[MedicationRecord] = Field(default_factory=list, max_length=20)
    appetite: Literal["unknown", "normal", "reduced", "increased"] = "unknown"
    symptoms: list[Literal["nausea", "vomiting", "early_fullness", "reflux",
                           "constipation", "diarrhea"]] = Field(default_factory=list, max_length=6)

    @field_validator("symptoms")
    @classmethod
    def unique_symptoms(cls, values):
        return list(dict.fromkeys(values))
