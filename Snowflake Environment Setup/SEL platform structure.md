# 🏗️ Platform Structure – South East London ICB

Welcome to the **Platform Structure** section of our repository!

This section provides an overview of how the **South East London Integrated Care Board (ICB)** structured their Snowflake platform to support logical partitioning, consistent object usage, version control, and future collaboration with other analytics teams across the Integrated Care System (ICS).

## 🧭 Purpose

Establishing a robust and scalable platform structure was crucial for ensuring:
- Clear separation of environments for testing, development, and production
- Logical partitioning of data using Raw, Staging, and Final schemas
- Consistent use of objects and versions of data across the team
- Future-proofing the platform to foster collaboration with other analytics teams

## 📐 Platform Structure

### Environments
- **Test**: Used for initial testing of new features, scripts, and data models.
- **Dev**: Used for development and refinement of features, scripts, and data models.
- **Prod**: Used for production-ready features, scripts, and data models.

### Schemas
- **Raw**: Contains raw, unprocessed data as ingested from source systems.
- **Staging**: Contains intermediate data that has undergone initial processing and transformation.
- **Final**: Contains fully processed and refined data ready for analysis and reporting.

## 🤝 Collaboration and Future-Proofing

By adopting this structured approach, South East London ICB ensures:
- Consistent and logical partitioning of data and environments
- Clear version control and object usage across the team
- A scalable and collaborative platform that can be easily extended to other analytics teams within the ICS

---

We hope this helps you understand our platform structure and supports your own Snowflake practices. If you have suggestions or improvements, feel free to contribute or open a discussion!
