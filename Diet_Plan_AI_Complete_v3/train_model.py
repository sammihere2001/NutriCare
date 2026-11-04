"""
Train the diet-plan model using the Pakistani meal-plan dataset.
"""

import json
import os
from datetime import datetime, timezone

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler

from diet_data_utils import DEFAULT_DATASET_PATH, normalize_dataframe

MODEL_METADATA_FILENAME = "training_metadata.json"


class DietPlanModel:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoders = {}
        self.feature_columns = []

    def prepare_features(self, df: pd.DataFrame):
        """Prepare model features from the normalized dataset."""
        print("[DATA] Preparing features...")
        data = normalize_dataframe(df)

        categorical_columns = ["gender", "activity_level", "goal", "dietary_preference"]
        for column in categorical_columns:
            encoder = LabelEncoder()
            data[f"{column}_encoded"] = encoder.fit_transform(data[column])
            self.label_encoders[column] = encoder

        data["has_diabetes_int"] = data["has_diabetes"].astype(int)
        data["uses_insulin_int"] = data["uses_insulin"].astype(int)

        # ADD THESE DERIVED FEATURES
        data["insulin_total"] = data["insulin_morning_units"] + data["insulin_night_units"]
        data["insulin_blood_sugar_ratio"] = data["insulin_total"] / (data["blood_sugar_level"] + 1)
        data["blood_sugar_risk"] = np.where(data["blood_sugar_level"] > 200, 2,
                                            np.where(data["blood_sugar_level"] > 140, 1, 0))
        data["bmi_risk"] = np.where(data["bmi"] > 30, 1, 0)

        # Add interaction features
        data["diabetes_insulin_interaction"] = data["has_diabetes_int"] * data["insulin_total"]
        data["age_bmi_risk"] = data["age"] * data["bmi_risk"]

        # Define feature columns AFTER creating derived features
        self.feature_columns = [
            "age",
            "weight_kg",
            "height_cm",
            "bmi",
            "gender_encoded",
            "activity_level_encoded",
            "goal_encoded",
            "dietary_preference_encoded",
            "has_diabetes_int",
            "uses_insulin_int",
            "insulin_morning_units",
            "insulin_night_units",
            "blood_sugar_level",
            "bmr",
            "tdee",
            "target_calories",
            "insulin_total",
            "insulin_blood_sugar_ratio",
            "blood_sugar_risk",
            "diabetes_insulin_interaction",
            "age_bmi_risk"
        ]

        X = data[self.feature_columns].fillna(0)
        X_scaled = self.scaler.fit_transform(X)
        return X_scaled, data

    def create_labels(self, data: pd.DataFrame):
        """Use each stored meal plan to derive a training label."""
        print("[LABEL] Creating plan labels from meal_plan...")
        return data["recommended_plan_type"].to_numpy()

    def train(self, X, y):
        """Train a random forest classifier."""
        print("[AI] Training Random Forest model...")
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=42,
            stratify=y,
        )

        self.model = RandomForestClassifier(
            n_estimators=300,
            max_depth=18,
            min_samples_split=4,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=1,
        )
        self.model.fit(X_train, y_train)

        y_pred = self.model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)

        print("\nOK Model training complete.")
        print(f"[TARGET] Accuracy: {accuracy * 100:.2f}%")
        print("\n[DATA] Classification Report:")
        print(classification_report(y_test, y_pred))

        feature_importance = pd.DataFrame(
            {
                "feature": self.feature_columns,
                "importance": self.model.feature_importances_,
            }
        ).sort_values("importance", ascending=False)

        print("\n[INFO] Top 10 important features:")
        print(feature_importance.head(10).to_string(index=False))
        return accuracy

    def save_model(self, model_dir="models", dataset_path=None, accuracy=None):
        """Persist the model artifacts."""
        if not os.path.exists(model_dir):
            os.makedirs(model_dir)

        joblib.dump(self.model, f"{model_dir}/diet_model.pkl")
        joblib.dump(self.scaler, f"{model_dir}/scaler.pkl")
        joblib.dump(self.label_encoders, f"{model_dir}/label_encoders.pkl")
        joblib.dump(self.feature_columns, f"{model_dir}/feature_columns.pkl")
        metadata = {
            "dataset_path": os.path.abspath(dataset_path) if dataset_path else "",
            "dataset_mtime": os.path.getmtime(dataset_path) if dataset_path and os.path.exists(dataset_path) else None,
            "trained_at": datetime.now(timezone.utc).isoformat(),
            "accuracy": float(accuracy) if accuracy is not None else None,
        }
        with open(f"{model_dir}/{MODEL_METADATA_FILENAME}", "w", encoding="utf-8") as metadata_file:
            json.dump(metadata, metadata_file, indent=2)

        print(f"\n[SAVE] Model artifacts saved in {model_dir}/")


def train_from_dataset(dataset_path=DEFAULT_DATASET_PATH, model_dir="models"):
    if not os.path.exists(dataset_path):
        print(f"[ERROR] Dataset not found: {dataset_path}")
        return None

    print(f"[FILE] Loading dataset: {dataset_path}")
    df = pd.read_csv(dataset_path)
    print(f"OK Loaded {len(df)} user meal plans")

    model = DietPlanModel()
    X, processed_df = model.prepare_features(df)
    y = model.create_labels(processed_df)

    print("\n[DATA] Label distribution:")
    unique_labels, counts = np.unique(y, return_counts=True)
    for label, count in zip(unique_labels, counts):
        print(f"   - {label}: {count} ({count / len(y) * 100:.1f}%)")

    print("\n[DATA] Dietary preference distribution:")
    print(processed_df["dietary_preference"].value_counts().to_string())

    accuracy = model.train(X, y)
    model.save_model(model_dir=model_dir, dataset_path=dataset_path, accuracy=accuracy)

    return accuracy


def main():
    dataset_path = DEFAULT_DATASET_PATH

    print("=" * 60)
    print("[DIET] PAKISTANI DIET PLAN MODEL TRAINING")
    print("=" * 60)

    accuracy = train_from_dataset(dataset_path=dataset_path)
    if accuracy is None:
        return

    print("\n" + "=" * 60)
    print("OK TRAINING COMPLETE")
    print(f"[TARGET] Final Accuracy: {accuracy * 100:.2f}%")
    print("=" * 60)


if __name__ == "__main__":
    main()