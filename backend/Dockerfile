# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart build cli --target bin/server.dart -o output

# Build minimal serving image from AOT-compiled `/server`
# and the pre-built AOT-runtime in the `/runtime/` directory of the base image.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/output/bundle/ /app/
# schema.sql and seeds are read at runtime from database/ relative to the working directory;
# the SQLite file (DB_PATH, default mangodata.db) is created there too.
COPY --from=build /app/database/ /app/database/
WORKDIR /app

# Start server.
EXPOSE 8080
CMD ["/app/bin/server"]
